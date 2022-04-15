uses System.Net;
uses System.Net.Sockets;

uses NetData;

procedure SendFile(fname: string; conn: SockConnection);
begin
  var bw := conn.CreateWriter;
  bw.Write(fname);
  
  var str := System.IO.File.OpenRead(fname);
  var l := str.Length;
//  Writeln(l);
  bw.Write(l);
  str.CopyTo(bw.BaseStream);
  str.Close;
  
end;

const BucketName = 'Bucket';

begin
  try
    System.IO.Directory.CreateDirectory(BucketName);
    
    var ipHostInfo := Dns.Resolve(Dns.GetHostName());
    var ipAddress := ipHostInfo.AddressList[0];
    var localEndPoint := new IPEndPoint(ipAddress, 10002);
    
    var listener := new Socket(
      AddressFamily.InterNetwork,
      SocketType.Stream,
      ProtocolType.Tcp
    );
    
    listener.Bind(localEndPoint);
    listener.Listen(1);
    
    $'Waiting at {ipAddress}'.Println;
    var conns := new List<SockConnection>;
    
    begin
      var fsw := new System.IO.FileSystemWatcher(BucketName, '*.exe');
      var to_send := new HashSet<string>;
      var send_time := default(DateTime?);
      
//      var last_update := new System.Collections.Concurrent.ConcurrentDictionary<string, DateTime>;
      
      var update := procedure(ch: System.IO.WatcherChangeTypes; del,add: string)->
      begin
//        lock output do $'{ch}: -[{del}]+[{add}]'.Println;
//        if add<>nil then
//        begin
//          var is_new_time := true;
//          
//          last_update.AddOrUpdate(add,
//            System.IO.File.GetLastWriteTime,
//            (key, prev_ut)->
//            begin
//              Result := System.IO.File.GetLastWriteTime(add);
//              $'Last updated {prev_ut}:{prev_ut.Millisecond}'.Println;
//              $'Curr updated {Result}:{Result.Millisecond}'.Println;
//              is_new_time := Result<>prev_ut;
//            end
//          );
//          
//          if not is_new_time then exit;
////          $'Last updated {send_time}:{send_time.Value.Millisecond}'.Println;
//        end;
        lock to_send do
        begin
          if del<>nil then to_send.Remove(del);
          if add<>nil then to_send += add;
        end;
        send_time := DateTime.Now.AddSeconds(0.5);
//        $'Send at {send_time}:{send_time.Value.Millisecond}'.Println;
      end;
      
      fsw.EnableRaisingEvents := true;
      fsw.Created += (o,e)->update(e.ChangeType,nil,e.FullPath);
      fsw.Changed += (o,e)->update(e.ChangeType,nil,e.FullPath);
      fsw.Renamed += (o,e)->update(e.ChangeType,e.OldFullPath,e.FullPath);
      fsw.Deleted += (o,e)->update(e.ChangeType,e.FullPath,nil);
      
      fsw.Error += (o,e)->
      lock output do
      begin
        'FileSystemWatcher error:'.Println;
        Println(e.GetException);
      end;
      
      System.Threading.Thread.Create(()->
      while true do
      try
        if send_time=nil then
        begin
          Sleep(10);
          continue;
        end;
        while send_time.Value>DateTime.Now do Sleep(0);
//        $'Sending at {DateTime.Now}:{DateTime.Now.Millisecond}'.Println;
        send_time := nil;
        
        var fls: array of string;
        lock to_send do
        begin
          fls := to_send.ToArray;
          to_send.Clear;
        end;
        lock output do
        begin
          foreach var f in fls do
            $'Sending [{f}]'.Println;
          ('='*30).Println;
        end;
        
        var curr_conns: array of SockConnection;
        lock conns do curr_conns := conns.ToArray;
        
        var broken_conns := new HashSet<SockConnection>;
        
        System.Threading.Tasks.Parallel.ForEach(curr_conns, conn->
        try
          foreach var f in fls do
            SendFile(f, conn);
          conn.FlushData;
        except
          on e: Exception do
          begin
            'Connection error:'.Println;
            Println(e);
            lock broken_conns do
            begin
              lock output do $'{conn} has disconnected'.Println;
              conn.Shutdown;
              broken_conns += conn;
            end;
          end;
        end);
        
        if broken_conns.Count<>0 then lock conns do
          conns.RemoveAll(c->c in broken_conns);
        
      except
        on e: Exception do
        begin
          'Sending error:'.Println;
          Println(e);
        end;
      end).Start;
      
    end;
    
    while true do
    begin
      var conn := new SockConnection(listener.Accept);
      lock output do $'{conn} has connected'.Println;
      lock conns do conns += conn;
    end;
    
  except
    on e: Exception do
    begin
      'General error:'.Println;
      Println(e);
    end;
  end;
  Readln;
  Halt;
end.
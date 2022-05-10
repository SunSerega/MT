uses System.Net;
uses System.Net.Sockets;

uses AOtp         in 'Utils\AOtp';
uses SubExecuters in 'Utils\SubExecuters';

uses NetData;

function ReceiveFile(br: System.IO.BinaryReader): string;
const file_copy_buff_size = 1024*1024*100;
begin
  var fname := br.ReadString;
  $'Receiving [{fname}]'.Println;
  System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(fname));
  
  var f := System.IO.File.Create(fname);
  var bw := new System.IO.BinaryWriter(f);
  var l := br.ReadInt64;
//  Writeln(l);
  
  while l>0 do
  begin
    var cl := Min(l, file_copy_buff_size);
    bw.Write(br.ReadBytes(cl));
    f.Flush;
    l -= cl;
  end;
  
  f.Close;
  Result := fname;
end;

begin
  try
    var ipHostInfo := Dns.Resolve(Dns.GetHostName());
    var ipAddress := ipHostInfo.AddressList[0];
    var ip_bts := ipAddress.GetAddressBytes;
    
    Write($'Connect to: {ip_bts[0]}.{ip_bts[1]}.{ip_bts[2]}.');
    
    ip_bts[3] := byte.Parse(ReadLexem);
    Readln;
    ipAddress := new System.Net.IPAddress(ip_bts);
    var remoteEP := new IPEndPoint(ipAddress, 10002);
    
    while true do
    begin
      var sock := new Socket(
        AddressFamily.InterNetwork,
        SocketType.Stream,
        ProtocolType.Tcp
      );
      try
        sock.Connect(remoteEP);
      except
        on e: Exception do
        begin
          $'Failed to connect to {remoteEP}:'.Println;
          Println(e);
          continue;
        end;
      end;
      
      var conn := new SockConnection(sock);
      Console.Title := $'Connected to {conn}'.Println;
      
      while true do
      try
        var fname := ReceiveFile(conn.CreateReader);
        Console.Clear;
        $'Running [{fname}]'.Println;
        SubExecuters.RunFile(fname, nil,
          l->Println($'[{fname}]: {l.s}'),
          e->Println($'[{fname}]: {e}')
        );
        $'Finished running [{fname}]'.Println;
      except
        on e: Exception do
          if not conn.IsConnected then
          begin
            $'Server disconnected'.Println;
  //          Println(e);
            break;
          end else
          begin
            'Test error:'.Println;
            Println(e);
          end;
      end;
      
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
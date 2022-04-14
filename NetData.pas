unit NetData;

interface

uses System.Net;
uses System.Net.Sockets;

type
  SockConnection = sealed class
    
    private sock: Socket;
    private otp_str := new System.IO.MemoryStream;
    
    
    public function IsConnected: boolean;
    begin
      Result := sock.Connected;
    end;
    
    public property CanRead: boolean read sock.Available<>0;
    
    
    private constructor := exit;
    public constructor(sock: Socket) := self.sock := sock;
    
    
    public function CreateReader: System.IO.BinaryReader;
    
    public function CreateWriter: System.IO.BinaryWriter;
    
    
    public procedure FlushData;
    
    public procedure WaitForData;
    
    public procedure WaitForData(t: System.TimeSpan);
    
    public procedure Shutdown;
    
    
    
    public function ToString: string; override :=
    sock.RemoteEndPoint.ToString;
    
  end;
  
implementation

type
  NetReceiveStream = class(System.IO.Stream)
    private conn: SockConnection;
    public constructor(conn: SockConnection) := self.conn := conn;
    
    private constructor :=
    raise new System.InvalidOperationException;
    
    private function GetNotSupported64: int64;
    begin
      Result := 0;
      raise new System.NotSupportedException;
    end;
    
    public property CanRead: boolean read boolean(true); override;
    
    public property CanSeek: boolean read boolean(false); override;
    
    public property CanTimeout: boolean read boolean(false); override;
    
    public property CanWrite: boolean read boolean(false); override;
    
    public property Length: int64 read GetNotSupported64; override;
    public property Position: int64 read GetNotSupported64 write raise new System.NotSupportedException; override;
    
    public procedure SetLength(value: int64); override := raise new System.NotSupportedException;
    public function Seek(offset: int64; origin: System.IO.SeekOrigin): int64; override := GetNotSupported64;
    
    public procedure Write(buffer: array of byte; offset: integer; count: integer); override :=
    raise new System.NotSupportedException;
    
    public procedure Flush; override :=
    raise new System.NotSupportedException;
    
    public function Read(buffer: array of byte; offset: integer; count: integer): integer; override;
    begin
//      while conn.sock.Available<>0 do Sleep(10);
      
//      begin
//        var i := offset;
//        loop count do
//        begin
//          buffer[i] := 123;
//          i += 1;
//        end;
//      end;
      
      Result := conn.sock.Receive(buffer, offset, count, SocketFlags.None);
//      $'rec {Result} of {count} bytes: {_ObjectToString(new System.ArraySegment<byte>(buffer, offset, Result))}'.Println;
      if Result=0 then conn.Shutdown;
    end;
    
  end;

{$region SockConnection}

{$region CreateIO}

function SockConnection.CreateReader := new System.IO.BinaryReader(new NetReceiveStream(self));
function SockConnection.CreateWriter := new System.IO.BinaryWriter(self.otp_str);

{$endregion CreateIO}

{$region IO}

procedure SockConnection.FlushData;
begin
  sock.Send(otp_str.ToArray);
  otp_str.SetLength(0);
end;

procedure SockConnection.WaitForData;
begin
  while sock.Available=0 do Sleep(10);
end;

procedure SockConnection.WaitForData(t: System.TimeSpan);
begin
  var ET := DateTime.UtcNow + t;
  while sock.Available = 0 do
    if DateTime.UtcNow < ET then
      Sleep(10) else
      raise new System.TimeoutException;
end;

procedure SockConnection.Shutdown;
begin
  sock.Shutdown(SocketShutdown.Both);
  sock.Close;
end;

{$endregion IO}

{$endregion SockConnection}

end.
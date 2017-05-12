defmodule Client do
  def main(args \\ []) do
    args
    |> process_args
  end
  def process_args(args) do    
    #opts for first   
    ip = List.to_string(args)
    case :inet_parse.address(ip |> to_charlist) do
      {:ok, ipAddress} -> Client.run(ipAddress,5000)
      _ -> IO.puts "Incorrect IP"
    end   
  end
  def run(ip,port) do
    case :gen_tcp.connect(ip,port,[:binary, packet: :raw, active: false]) do
      {:ok, server} ->	    
	    pid = spawn fn -> writeLine(server) end
        output(server,pid)
      {:error, _} -> IO.puts "Error with Connection"
    end
  end
  defp writeLine(connection) do
    msg = IO.gets ">>"
    case :gen_tcp.send(connection, msg) do
      :ok -> writeLine(connection)
      _ -> IO.puts "Things broke..."
    end
  end  
  defp output(connection,pid) do
    case :gen_tcp.recv(connection,0) do 
      {:ok, response} ->
        case response do
          "" -> 
            IO.puts "Sending quit"
            send pid, {:quit}
          response ->
            IO.puts "Server: " <> response |> String.trim_trailing         
            output(connection,pid)
        end
      {:error, :closed} -> IO.puts "Closed"
      _ -> output(connection,pid)
    end
  end

end

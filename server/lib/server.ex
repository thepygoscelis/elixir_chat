#Author: Charlie R. Hicks
defmodule Server do
  def main(args \\ []) do
    parse_args(args)

  end
  def parse_args(args) do
    start_server(5000)
  end
  defp keyStore(socket) do
    clients = Map.new()
    listeners = Map.new()
#    {_,{ip,_}} = :inet.peername(socket)       
    runningTotal = 1
    clients = Map.put_new(clients, runningTotal, socket)
    listeners = Map.put_new(listeners, runningTotal, spawn fn -> listenLoop(socket,runningTotal) end)
    runningTotal = runningTotal + 1
    processReceive(clients,listeners,runningTotal)
  end
  defp processReceive(clients,listeners,runningTotal) do
    receive do
      {:send, "whois:\n"} ->
        IO.puts "Clients"
        Enum.map(Map.keys(clients),fn (x) -> IO.puts x end)
        processReceive(clients,listeners,runningTotal)
      {:send, msg} ->
        privateMsg = ~r/^(?<number>[\d]+):(?<msg>.*)/
        killMsg = ~r/^(?<number>[\d]+)d:$/
        case Regex.named_captures(privateMsg,msg) do
          %{"msg" => msg, "number" => number} -> 
            n = number |> Integer.parse |> elem(0)
            case Map.get(clients, n) do
              x when not is_nil(x) ->
                :gen_tcp.send(Map.get(clients,n), msg)
                _ -> IO.puts "Invalid client"
            end
          _ -> case Regex.named_captures(killMsg, msg) do
                 %{"number" => number} ->
                   n = number |> Integer.parse |> elem(0)
                   case Map.get(clients, n) do
                     nil -> 
                       IO.puts "Invalid Client" 
                     x  ->
                       :gen_tcp.send(Map.get(clients,n), "")
                       Process.exit(Map.get(listeners, n), :kill)
                       :gen_tcp.close(Map.get(clients,n))
                       clients = Map.delete(clients,n)
                       listeners = Map.delete(listeners,n)

                   end
                   _ -> IO.puts "Invalid Command"
               end
        end
        processReceive(clients,listeners,runningTotal)
      {:add, client} ->
        clients = Map.put_new(clients, runningTotal, client)
        listeners = Map.put_new(listeners, runningTotal, spawn fn -> listenLoop(client,runningTotal) end)
        runningTotal = runningTotal + 1
        processReceive(clients,listeners,runningTotal)
      _ -> IO.puts "Made it here"
    end
  end
  defp acceptLoop(socket,pid) do
        {:ok, client} = :gen_tcp.accept(socket)
	    #spawn fn -> messageLoop(client) end
        send pid, {:add, client}
        acceptLoop(socket,pid)
  end
  def start_server(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :raw, active: false, reuseaddr: true])
    {:ok, client} = :gen_tcp.accept(socket)
    keystore = spawn fn -> keyStore(client) end
	spawn fn -> messageLoop(keystore) end
    acceptLoop(socket,keystore)
    #Left this in case I need IP address again.
    #	{_,{ip,_}} = :inet.peername(client)       
  end
  def listenLoop(connection, number) do
    receive do
      {:quit} ->
        IO.puts "Client " <> (number |> Integer.to_string) <> ": disconnected"
    after 200 ->
        case :gen_tcp.recv(connection,0) do
          {:ok, response} ->
            IO.puts "Client-" <> (number |> Integer.to_string) <> ": " <> response |> String.trim_trailing
            listenLoop(connection,number)
          _ -> IO.puts "Client Crashed"
        end
    end
  end
  #Writing
  defp messageLoop(pid) do
    pid
    |> writeLine
    messageLoop(pid)
  end  
  defp writeLine(pid) do
    msg = IO.gets ">>"
    send pid, {:send, msg}
  end
end

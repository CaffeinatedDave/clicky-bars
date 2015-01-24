require 'sinatra'
require 'sinatra-websocket'
require 'json'

set :server, 'thin'
set :bind, '0.0.0.0'
$sockets = []

$maxServerBar = 200
$bar = 0

def makeUpdateJson
  ret = {}
  ret["message"]  = "update"
  ret["barCap"]   = $maxServerBar
  ret["barState"] = "%.2f" % $bar
  ret["users"]    = $sockets.count
  return ret.to_json 
end

get '/' do
  if !request.websocket?
    erb :index
  else
    request.websocket do |ws|
      ws.onopen do |hs|
        warn(hs.to_s)
        $sockets << ws
        setup = makeUpdateJson
        ws.send(setup)
      end
      ws.onmessage do |msg|
        warn("received" + msg)
        json = JSON.parse(msg)
        if json["action"] = "claim"
          award = $bar
          $bar = 0
          ws.send({"message" => "award", "amount" => award}.to_json)
        end

        EM.next_tick do
          send = makeUpdateJson
          $sockets.each do |s|
            s.send(send)
          end
        end
      end
      ws.onclose do
        warn("websocket closed")
        $sockets.delete(ws)
      end
    end
  end
end

$tick = Time.now.to_i

Thread.new do 
  while true do
    while $tick < Time.now.to_i do
      $bar += (0.2 * $sockets.count)
      if $bar > $maxServerBar 
        $bar = $maxServerBar
      end
      EM.next_tick do
        send = makeUpdateJson
        $sockets.each do |s|
          s.send(send)
        end
      end
      $tick += 1
    end
    sleep 1
  end
end

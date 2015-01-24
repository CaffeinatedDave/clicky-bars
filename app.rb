require 'sinatra'
require 'sinatra-websocket'
require 'json'

set :server, 'thin'
set :bind, '0.0.0.0'
$sockets = []

$perSec = 1
$maxServerBar = 200
$bar = 53

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
        case json["action"] 
          when "steal"
            award = $bar
            $bar = 0
            ws.send({"message" => "award", "amount" => award}.to_json)
          when "donate"
            pure = json["amount"]
            $perSec += 0.05 * (pure / 100)
            $maxServerBar += pure / 5
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
      $bar += $perSec + ($perSec * ($bar / 10))
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

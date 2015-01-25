require 'sinatra'
require 'sinatra-websocket'
require 'json'
require './models/resource'

set :server, 'thin'
set :bind, '0.0.0.0'
$sockets = []

$resource = []

$resource << Resource.new("wood", 200, 1, 80)

def makeUpdateJson
  ret = {}
  ret["message"]  = "update"
  ret["users"] = $sockets.count
  ret["resource"] = {}

  $resource.each do |r|
    ret["resource"][r.name] = {}
    ret["resource"][r.name]["label"]  = r.name
    ret["resource"][r.name]["incr"]   = r.incr
    ret["resource"][r.name]["max"]    = r.max
    ret["resource"][r.name]["amount"] = "%d" % r.current
  end

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
        type = json["type"]
        case json["action"] 
          when "chat"
            send = {
              "message" => "chat",
              "who" => json["name"],
              "msg" => json["message"]
            }.to_json
            $sockets.each do |s|
              s.send(send)
            end
          when "steal"
            res = $resource.select{ |r| r.name == type}
            if res[0] != nil 
              award = res[0].steal(json["amount"])
              ws.send({
                "message" => "award",
                "type" => type,
                "amount" => award
              }.to_json)
            end
          when "donate"
            amount = json["amount"]
            res = $resource.select{ |r| r.name == type}
            if res[0] != nil 
              res[0].donate(amount)
            end
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

Thread.new do 
  while true do
    $resource.each do |r|
      r.tick
      new = r.rewards
      new.each do |n|
        $resource << n
      end
    end

    EM.next_tick do
      send = makeUpdateJson
      $sockets.each do |s|
        s.send(send)
      end
    end
    sleep 1
  end
end

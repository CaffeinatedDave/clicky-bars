require 'sinatra'
require 'sinatra-websocket'
require 'json'
require './models/resource'
require './models/users'

set :server, 'thin'
set :bind, '0.0.0.0'
$sockets = []

$resource = []
$users    = []

$resource << Resource.new("wood", 200, 1, 80)

def makeUpdateJson(whoami)
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

def broadcastMessage(who, msg)
  send = {
    "message" => "chat",
    "who"     => who, 
    "msg"     => msg 
  }.to_json
  $sockets.each do |s|
    s.send(send)
  end
end

get '/' do
  if !request.websocket?
    erb :index
  else
    request.websocket do |ws|
      me = User.new(Array.new(12){[*"A".."F", *"0".."9"].sample}.join)
      warn(me.trip + " connected...")
      ws.onopen do |hs|
        warn(hs.to_s)
        $sockets << ws
        setup = makeUpdateJson(me)
        ws.send(setup)
        broadcastMessage("system", me.trip + " joined the game")
      end
      ws.onmessage do |msg|
        warn(me.trip + "received" + msg)
        json = JSON.parse(msg)
        type = json["type"]
        case json["action"] 
          when "chat"
            me.set_name(json["name"])
            if json["message"] != ""
              broadcastMessage(me.name, json["message"])
            end
          when "steal"
            if me.is_allowed?
              me.update_allowed
              res = $resource.select{ |r| r.name == type}
              if res[0] != nil 
                award = res[0].steal(json["amount"].to_i)
                ws.send({
                  "message" => "award",
                  "type" => type,
                  "amount" => award
                }.to_json)
                broadcastMessage("system", me.name + " stole " + award.to_s + " " + type + "!")
              end
            else
              send = {
                "message" => "chat",
                "who"     => "system", 
                "msg"     => "Stop being greedy, you can't steal again until " + me.allowed.to_s 
              }.to_json
              ws.send(send)
            end
          when "donate"
            amount = json["amount"].to_i
            res = $resource.select{ |r| r.name == type}
            if res[0] != nil 
              res[0].donate(amount)
            end
            broadcastMessage("system", me.name + " donated " + amount.to_s + " " + type + "!")
          end

        EM.next_tick do
          send = makeUpdateJson(me)
          $sockets.each do |s|
            s.send(send)
          end
        end
      end
      ws.onclose do
        warn(me.trip + "websocket closed")
        $sockets.delete(ws)
        broadcastMessage("system", me.trip + " left the game")
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
      send = makeUpdateJson(nil)
      $sockets.each do |s|
        s.send(send)
      end
    end
    sleep 1
  end
end

require './models/resource'

class User
  attr_reader :trip, :name, :allowed, :state

  def initialize(trip)
    @trip    = trip
    @name    = trip
    @allowed = Time.now
    @camp    = {}
    @camp["resources"] = {}
    @camp["buildings"] = {}
  end

  def set_name(name)
    if name != ""
      @name = name
    end
  end

  def update_allowed(amount)
    if (amount >= 0)
      @allowed = Time.now + 1 + amount/20
    else
      @allowed = @allowed + amount/20
    end
  end

  def is_allowed
    @allowed - Time.now
  end

  def saveState(thing) 
    
  end

  def getState
    state = {}
    camp["resources"].each do |r|
      state["resources"][r.name] = {
        label: r.name,
        current: r.current,
        max: r.max
      }
    end
  end
end

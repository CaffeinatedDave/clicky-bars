class User
  attr_reader :trip, :name, :allowed, :state

  def initialize(trip)
    @trip    = trip
    @name    = trip
    @allowed = Time.now
    @state   = {}
  end

  def set_name(name)
    if name != ""
      @name = name
    end
  end

  def update_allowed(amount)
    @allowed = Time.now + amount/20
  end

  def is_allowed?
    if Time.now > @allowed
      return true
    else
      return false
    end
  end

  def saveState(thing) 
  end
end

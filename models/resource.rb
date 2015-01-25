class Resource
  attr_reader :name, :max, :incr, :current

  def initialize(name, max, incr, current)
    @name    = name
    @max     = max
    @incr    = incr
    @current = current
    @rewarded = 0
  end

  def tick 
    myIncr = @incr + (@incr * 10 * (@current * 1.0 / @max)) 
    if (@current + myIncr) > @max
      @current = @max
    else 
      @current += myIncr
    end
  end

  def steal(amount)
    if @current > amount
      stolen = amount
      @current -= amount
    else
      stolen = @current
      @current = 0
    end

    return stolen
  end

  def donate(amount)
    @incr += 0.01 * (amount / 100)
    @max  += amount / 5
  end

  # just demo for now...
  def rewards
    case @name
      when "wood"
        if (@current > 200 && @rewarded == 0)
          @rewarded = 1
          return [Resource.new("stone", 200, 1, 5)]
        elsif (@current > 500 && @rewarded == 1)
          @rewarded = 2
          return [Resource.new("iron", 100, 0.2, 0)]
        end
      when "iron"
        if (@current > 100 && @rewarded == 0)
          @rewarded = 1
          return [Resource.new("oil", 100, 0.2, 0)]
        end
      end
    return []
  end
end

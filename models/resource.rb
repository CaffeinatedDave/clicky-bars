class Resource
  attr_reader :name, :max, :incr, :current

  def initialize(name, max, incr, current, tick)
    @name    = name
    @max     = max
    @incr    = incr
    @current = current
    @tick_func = tick
  end

  def tick 
    if @max > 0
      @current = @tick_func.call(@current, @max, @incr)
    end
    if @current > @max
      @current = @max
    end
  end

  def steal(amount)
    if amount > 0
      if @current > amount
        stolen = amount
        @current -= amount
      else
        stolen = @current
        @current = 0
      end
    end

    return stolen.to_i
  end

  def build(action)
    @max += action["max"].to_i
    @incr += action["incr"].to_f
  end

end

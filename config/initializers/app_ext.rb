
# 40.percent_of_the_time do
class Fixnum
  def percent_of_the_time(&block)
    yield if (Kernel.rand(100)+1) <= self
  end
end

# (3..6).times do
class Range
  def times(&block)
    Random.rand(self).times(&block)
  end
end

#中英文字符 长度验证 英文按照半个中文处理
class String

  def is_longer_than(sum)
    if self.length > sum and self.bytesize > 2*sum
      return true
    else
      return false
    end
  end

  def not_longer_than(sum)
    if self.length <= sum or self.bytesize <= 2*sum
      return true
    else
      return false
    end
  end
end

class Object
  def confirm
    self if self
  end
end

class TrueClass
  def to_i
    1
  end
end

class FalseClass
  def to_i
    0
  end
end

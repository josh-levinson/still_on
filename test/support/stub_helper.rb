# Minitest 6 removed Object#stub. This restores the minitest 5 implementation
# so existing tests don't need to be rewritten.
class Object
  def stub(name, val_or_callable, *block_args, **block_kwargs, &block)
    new_name = "__minitest_stub__#{name}"
    metaclass = class << self; self; end

    if respond_to?(name) && !methods.map(&:to_s).include?(name.to_s)
      metaclass.define_method(name) { |*args, **kwargs| super(*args, **kwargs) }
    end

    metaclass.alias_method(new_name, name)
    metaclass.define_method(name) do |*args, **kwargs, &blk|
      if val_or_callable.respond_to?(:call)
        kwargs.empty? ? val_or_callable.call(*args, &blk) : val_or_callable.call(*args, **kwargs, &blk)
      else
        blk&.call(*block_args, **block_kwargs)
        val_or_callable
      end
    end

    block.call(self)
  ensure
    metaclass.undef_method(name)
    metaclass.alias_method(name, new_name)
    metaclass.undef_method(new_name)
  end
end

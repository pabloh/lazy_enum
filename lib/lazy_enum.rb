class Object
  def to_lazy met = :each
    Enumerator::Lazy.from_object(self, met)
  end
end

module Math
  Naturals = 0..Float::INFINITY 
  Nat = Naturals
end

module Enumerable
  alias_method :lazy, :to_lazy
end

class Enumerator
  class Lazy
    include ::Enumerable

    def self.from_object(enum, met = :each, *args)
      self.new Enumerator, enum, met, *args
    end

    def initialize(klass, *params, &bl)
      @enum_class, @params, @block = klass, params, bl
    end

    def each
      enum = next_link
      loop { yield enum.next }
    rescue StopIteration 
      self
    end 

    def select &bl
      block_given? ? Lazy.new(Filter, self, &bl) : to_enum(:select)
    end
 
    def reject &bl
      block_given? ? select {|obj| !yield(obj) } : to_enum(:reject)
    end

    def flat_map &bl
      block_given? ? Lazy.new(FlatTransform, self, &bl) : to_enum(:flat_map)
    end
   
    def map &bl
      block_given? ? Lazy.new(Transform, self, &bl) : to_enum(:map)
    end

    def grep pattern
      select {|obj| pattern === obj }.tap do |res|
        res.each(&bl) if block_given?
      end
    end

    def zip(*others, &bl)
      Lazy.new(Zipper, self, *others).tap do |res|
        res.each(&bl) if block_given?
      end
    end

    def cycle
      Lazy.new(Cycler, self)
    end

    def drop_while &cond
      if block_given?
        active = nil
        select {|obj| active || (!yield(obj) && active = true) }
      else to_enum(:drop_while)
      end
    end

    def drop count
      i = 0
      drop_while { (i < count).tap { i+=1 } }
    end

    alias_method :collect, :map
    alias_method :collect_concat, :flat_map
    alias_method :find_all, :select

    
    [:find, :find_index, :partition, :group_by, :sort_by, :min_by, :max_by, 
      :minmax_by, :each_with_index, :reverse_each, :each_entry, :each_slice, 
      :each_cons, :each_with_object, :take_while].each do |met|

      define_method(met) do |*args, &bl|
        bl ? super(*args, &bl) : to_enum(met, *args)
      end
    end

  #TODO: :chunk, :slice_before
    
    def to_enum met = :each, *args
      met == :each ? self : Lazy.from_object(self, met, *args)
    end

    def next_link
      @enum_class.new(*@params, &@block)
    end

    class Pipe
      include Enumerable
      def initialize prev
        @enum = to_enum_or_pipe(prev)
      end

      def next
        @enum.next
      end

    protected
      def to_enum_or_pipe prev
        prev.is_a?(Lazy) ? prev.next_link : prev.to_enum
      end
    end

    class Filter < Pipe
      def initialize prev, &cond
        super(prev)
        @cond = cond
      end

      def next
        while !@cond.call(val = super); end
        val
      end
    end

    class Transform < Pipe
      def initialize prev, &tfunc
        super(prev)
        @transform = tfunc
      end

      def next
        @transform.call( super )
      end
    end

    class FlatTransform < Pipe
      def initialize prev, &tfuct
        super(prev)
        @transform, @values = tfunc, []
      end

      def next
        @values.concat Array(super).flatten if values.empty?

        @transform.call(@values.shift)
      end
    end

    class Zipper < Pipe
      def initialize prev, *others
        super(prev)
        @others = others.map {|other| to_enum_or_pipe(other) }
      end

      def next
        [super] + @others.map do |other|
          begin
            other.next
          rescue StopIteration
            nil
          end
        end
      end
    end
    
    class Cycler < Pipe
      def initialize prev
        super
        @prev = prev
      end
      def next
        super.tap { @called = true unless @called }
      rescue StopIteration
        if @called
          @enum = to_enum_or_pipe(@prev)
          retry 
        else 
          raise
        end
      end
    end

  end
end

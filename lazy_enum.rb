class Object
  def to_lazy met = :each
    Enumerator::Lazy.from_object(self, met)
  end
end

module Math
  Naturals = 0..Float::INFINITY 
end

class Enumerator
  class Lazy
    include ::Enumerable

    def self.from_object(enum, met = :each)
      self.new Enumerator, enum, met
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
      Lazy.new(Filter, self, &bl)
      #TODO: No block given
    end
 
    def reject &bl
      Lazy.new(Filter.new(self) {|obj| !yield(obj) })
      #TODO: No block given
    end

    def flat_map &bl
      Lazy.new(FlatTransform, self, &bl)
      #TODO: No block given
    end
   
    def map &bl
      Lazy.new(Transform, self, &bl)
      #TODO: No block given
    end

    def grep pattern
      Lazy.new(Filter, self) {|obj| pattern === obj }.tap do |res|
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
      #TODO: No block given
      active = nil
      select {|obj| active || (!yield(obj) && active = true) }
    end

    def drop count
      i = 0
      drop_while { (i < count).tap { i+=1 } }
    end

    alias_method :collect, :map
    alias_method :collect_concat, :flat_map
    alias_method :find_all, :select

  #TODO: :chunk, :each_cons, :each_slice, :slice_before

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

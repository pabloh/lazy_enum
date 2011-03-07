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
      @enum_class, (@first_param, *@other_params), @block = klass, params, bl
    end

    def each
      enum = get_enumerator
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

  protected
    def get_enumerator
      first_param = @first_param.is_a?(Lazy) ? @first_param.get_enumerator : @first_param
      @enum_class.new(first_param, *@other_params, &@block)
    end

    class Pipe
      def initialize prev
        @prev = prev
      end

      def next
        @prev.next
      end
    end

    class Filter < Pipe
      def initialize prev, &cond
        @prev, @cond = prev, cond
      end

      def next
        while !@cond.call(val = super); end
        val
      end
    end

    class Transform < Pipe
      def initialize prev, &tfunc
        @prev, @tfunc = prev, tfunc
      end

      def next
        @tfunc.call( super )
      end
    end

    class FlatTransform < Pipe
      def initialize prev, &tfuct
        @prev, @tfunc, @values = prev, tfunc, []
      end

      def next
        @values.concat Array(super).flatten if values.empty?

        @tfunc.call(@values.shift)
      end
    end

    class Zipper < Pipe
      def initialize prev, *others
        @prev, @others = prev, others.map {|other| other.to_enum }
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
  end
end

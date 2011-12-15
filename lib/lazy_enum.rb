class Object
  def to_lazy method = :each
    Enumerable::Lazy.new self.to_enum(method)
  end

  def apply msg, *args
    ->(*bargs) { self.public_send msg, *args, *bargs }
  end
end

module Math
  Naturals = 0..Float::INFINITY 
  Nat = Naturals
end

def lazy_enum &block
  Enumerable::Lazy.new Enumerator.new(&block)
end

module Enumerable
  alias_method :lazy, :to_lazy

  def to_lazy
    Enumerable::Lazy.new self
  end

  class Lazy
    include ::Enumerable

    def initialize(source)
      @source = source.respond_to?(:next) ? source : source.to_enum
    end

    def each
      source = @source
      loop { yield source.next }
    rescue StopIteration 
      self
    end 

    def select &bl
      block_given? ? Lazy.new(Filter.new(@source, &bl)) : no_block_given_error
    end
 
    def reject &bl
      block_given? ? select {|obj| !yield(obj) } : no_block_given_error
    end

    def flat_map &bl
      block_given? ? Lazy.new(FlatTransformer.new(@source, &bl)) : no_block_given_error
    end
   
    def map &bl
      block_given? ? Lazy.new(Transformer.new(@source, &bl)) : no_block_given_error
    end

    def grep pattern
      select {|obj| pattern === obj }.tap do |res|
        res.each(&bl) if block_given?
      end
    end

    def zip(*others, &bl)
      Lazy.new(Zipper.new(@source, *others)).tap do |res|
        res.each(&bl) if block_given?
      end
    end

    def cycle
      Lazy.new(Cycler, self)
    end

    def drop_while &cond
      if block_given?
        active = nil
        select {|obj| active || !yield(obj) && active = true }
      else no_block_given_error
      end
    end

    def drop count
      i = 0
      drop_while { (i < count).tap { i+=1 } }
    end
    
    def take_while &bl
      if block_given?
        select {|obj| yield(obj) || raise(StopIteration.new) }
      else
        no_block_given_error
      end
    end

    alias_method :collect, :map
    alias_method :collect_concat, :flat_map
    alias_method :find_all, :select

    
    # Instant result methods
    [:find, :find_index, :partition, :group_by, :sort_by, :min_by, :max_by, 
      :minmax_by, :each_with_index, :reverse_each, :each_entry, :each_slice, 
      :each_cons, :each_with_object, :any?, :one?, :all?].each do |met|

      define_method(met) do |*args, &block|
        block_given? ? no_block_given_error : super(*args, &block)
      end
    end

   #TODO: :chunk, :slice_before
    
    def to_enum met = :each, *args
      met == :each ? self : Lazy.from_object(self, met, *args)
    end
    
  protected
  
    def no_block_given_error
      raise LocalJumpError.new "no block given"
    end

    def next_link
      @enum_class.new(*@params, &@block)
    end


    class Pipe #abstract class
      attr :source
      
      def initialize source
        @source = source
      end

      def next
        @source.next
      end
    end

    class Filter < Pipe
      def initialize prev, &cond
        super prev
        @filter = cond
      end

      def next
        nil until @filter.call(val = super)
        val
      end
    end

    class Transformer < Pipe
      def initialize prev, &transformer
        super
        @transformer = transformer
      end

      def next
        @transformer.call( super )
      end
    end

    class FlatTransformer < Pipe
      def initialize prev, &tfuct
        super
        @transform, @values = tfunc, []
      end

      def next
        @values.concat Array(super).flatten if values.empty?

        @transform.call(@values.shift)
      end
    end

    class Zipper < Pipe
      def initialize prev, *others
        super
        @others = others.map {|other| other }
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
          @source = to_enum_or_pipe(@prev)
          retry 
        else 
          raise
        end
      end
    end

  end
end

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
      @source.rewind
      loop { yield @source.next }
    rescue StopIteration
      self
    end

    def select &block
      block_given? ? Lazy.new(Filter.new(@source, &block)) : no_block_given_error
    end

    def reject
      block_given? ? select {|obj| !yield(obj) } : no_block_given_error
    end

    def flat_map &block
      block_given? ? Lazy.new(FlatTransformer.new(@source, &block)) : no_block_given_error
    end

    def map &block
      block_given? ? Lazy.new(Transformer.new(@source, &block)) : no_block_given_error
    end

    def grep pattern, &block
      select {|obj| pattern === obj }.tap do |res|
        res.each(&block) if block_given?
      end
    end

    def zip(*others, &block)
      Lazy.new(Zipper.new(@source, *others)).tap do |res|
        res.each(&block) if block_given?
      end
    end

    def drop_while
      if block_given?
        dropping = true
        reject {|obj| dropping && (yield(obj) || dropping = false) }
      else no_block_given_error
      end
    end

    def drop count
      i = 0
      drop_while { (i += 1) <= count }
    end

    def take_while
      if block_given?
        select {|obj| yield(obj) || raise(StopIteration.new) }
      else
        no_block_given_error
      end
    end

    def take count
      i = 0
      take_while { (i += 1) <= count }
    end

    alias_method :collect, :map
    alias_method :collect_concat, :flat_map
    alias_method :find_all, :select


    # Methods that already return enumerators
    [:cycle, :slice_before, :chunk].each do |name|
      define_method(name) do |*args, &block|
        Lazy.new super(*args, &block)
      end
    end


    # Instant result methods w/block
    [:find, :detect, :find_index, :partition, :group_by, :sort_by, :min_by,
      :max_by, :minmax_by, :any?, :one?, :all?, :each_with_index, :reverse_each,
      :each_slice, :each_cons, :each_with_object, :each_entry ].each do |name|

      define_method(name) do |*args, &block|
        block_given? ? no_block_given_error : super(*args, &block)
      end
    end

  protected

    def no_block_given_error
      raise LocalJumpError.new "no block given"
    end

    class Pipe #abstract class
      attr :source

      def initialize source
        @source = source
      end

      def next
        @source.next
      end

      def rewind
        @source.rewind
      end
    end

    class Filter < Pipe
      def initialize source, &cond
        super
        @filter = cond
      end

      def next
        nil until @filter.call(val = super)
        val
      end
    end

    class Transformer < Pipe
      def initialize source, &transformer
        super
        @transformer = transformer
      end

      def next
        @transformer.call super
      end
    end

    class FlatTransformer < Pipe
      def initialize source, &transformer
        super
        @transform, @values = transformer, []
      end

      def next
        @values.concat Array(super).flatten if @values.empty?

        @transform.call(@values.shift)
      end

      def rewind
        super
        @values.clear
      end
    end

    class Zipper < Pipe
      def initialize source, *enums
        super source
        @others = enums.map {|enum| enum.respond_to?(:next) ? enum : enum.to_enum }
      end

      def next
        @others.map do |other|
          begin
            other.next
          rescue StopIteration
            nil
          end
        end.unshift(super)
      end

      def rewind
        super
        @others.each {|other| other.rewind }
      end
    end

  end
end

class Object
  def to_lazy_enum method = :each
    self.to_enum(method).lazy
  end

  def apply msg, *args
    ->(*bargs) { self.public_send msg, *args, *bargs }
  end
end

module Math
  Naturals = 0..Float::INFINITY
  Nat = Naturals
end

module Enumerable
  def to_lazy
    Lazy.new self
  end

  alias_method :lazy, :to_lazy

  class Lazy
    include ::Enumerable

    def to_enum method = :each
      method == :each ? super : super().to_enum(method)
    end

    def self.new *args, &block
      block_given? ? Enumerator.new(&block).lazy : super
    end

    def initialize(source)
      @source = source.respond_to?(:next) ? source : source.to_enum
    end

    def each
      return self unless block_given?

      @source.rewind
      loop { yield @source.next } || self
    end

    # 'Lazyfied' methods
    def select &block
      block_given? ? Lazy.new(Filter.new(@source, &block)) : to_lazy_enum(:select)
    end

    def reject
      block_given? ? select {|obj| !yield(obj) } : to_lazy_enum(:reject)
    end

    def map &block
      block_given? ? Lazy.new(Transformer.new(@source, &block)) : to_lazy_enum(:map)
    end

    def flat_map &block
      block_given? ? Lazy.new(FlatTransformer.new(@source, &block)) : to_lazy_enum(:flat_map)
    end

    def drop_while
      if block_given?
        dropping = true
        reject {|obj| dropping && (yield(obj) || dropping = false) }
      else
        to_lazy_enum :drop_while
      end
    end

    def take_while
      if block_given?
        select {|obj| yield(obj) || raise(StopIteration.new) }
      else
        to_lazy_enum :take_while
      end
    end

    def grep pattern, &block
      res = select {|obj| pattern === obj }
      block_given? ? res.map(&block).to_a : res
    end

    def drop count
      i = 0
      drop_while { (i += 1) <= count }
    end

    def take count
      i = 0
      take_while { (i += 1) <= count }
    end

    def zip(*others, &block)
      res = Lazy.new(Zipper.new(@source, *others))
      block_given? ? res.each(&block) && nil : res
    end


    alias_method :collect, :map
    alias_method :collect_concat, :flat_map
    alias_method :find_all, :select


    # Methods that always return enumerators
    %w[slice_before chunk].each do |method|
      class_eval "def #{method} *args; super.lazy; end"
    end


    # Methods that return enums when no block is given
    [ [ %w[partition group_by sort_by min_by max_by minmax_by], ''],
      [ %w[each_slice each_cons each_with_object], 'arg'],
      [ %w[each_with_index reverse_each each_entry cycle find
        detect find_index], '*args'] ].each do |methods, arguments|

      methods.each do |method|
        class_eval <<-METHOD_DEF
          def #{method} #{arguments}
            block_given? ? super : super.lazy
          end
        METHOD_DEF
      end
    end


    # Decorator classes with lazyfied behaviour
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

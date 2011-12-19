require 'spec_helper'
require 'lazy_enum'

describe Enumerable::Lazy do
  let (:lazy_range)  { (0..1_000_000_000).lazy }
  let (:mocked_block) { mock('block') }


  describe ".new" do
    context "when no block is given" do
      subject { Enumerable::Lazy.new(1..15) }

      it { should be_kind_of(Enumerable::Lazy) }
      it "should decorate the passed argument using a Enumerable::Lazy" do
        enum = (1..15).to_enum
        subject.each {|element| element.should == enum.next }
      end
    end

    context "when a block is given" do
      subject { Enumerable::Lazy.new {|y| 3.times {|x| y << x} } }

      it { should be_kind_of(Enumerable::Lazy) }
      it "should create a decorated Enumerator using the given block" do
        enum = 3.enum_for :times
        subject.each {|element| element.should == enum.next }
      end
    end
  end


  describe "#to_enum" do
    subject { lazy_range.to_enum }

    it "should return an enumerable wrapping the receiver"
    it { should be_kind_of(Enumerator) }
    context "with a parameter different to :each" do
      it "should return and enumerator encapsulating the Enumerable's implementation for the method"
    end
  end

  describe "#to_a" do
    it "should instantiate the enumerable's results" do
      (0..99).lazy.to_a.should == [*0..99]
    end
  end

  describe "#each" do
    context "when no block is given" do
      it "should return itself" do
        lazy_range.each.should equal(lazy_range)
      end
    end

    context "when a block is given" do
      let (:lazy_array) { [3,4].lazy }
      it "should iterate over the decorated enumerable" do
        [4,3].each {|n| mocked_block.should_receive(:call).with(n) }
        lazy_array.each {|n| mocked_block.call(n) }
      end
      it "should return itself" do
        lazy_array.each {}.should equal(lazy_array)
      end
    end
  end


  # 'Lazyfied' methods
  describe "#select" do
    context "when a block is given" do
      subject { lazy_range.select {|x| x > 3 } }

      it "should return an enumerable which filters elements from the decorated enumerable" do
        subject.take(10).should == [*4..13]
      end
      it { should be_kind_of(Enumerable::Lazy) }
    end
    context "when no block is given" do
      subject { lazy_range.select }
      it "should return a lazy enumerable encapsulating Enumerable#select"
      it { should be_kind_of(Enumerable::Lazy) }
    end
  end

  describe "#reject" do
    context "when a block is given" do
      subject { lazy_range.reject {|x| x < 3 } }

      it "should return an enumerable which excludes elements from the decorated enumerable" do
        subject.take(10).should == [*3..12]
      end
      it { should be_kind_of(Enumerable::Lazy) }
    end
    context "when no block is given" do
      subject { lazy_range.reject}
      it "should return a lazy enumerable encapsulating Enumerable#reject"
      it { should be_kind_of(Enumerable::Lazy) }
    end
  end

  describe "#map" do
    context "when a block is given" do
      subject { lazy_range.map {|x| x + 3 } }

      it "should return an enumerable which maps over the decorated enumerable" do
        subject.take(10).should == [*3..12]
      end
      it { should be_kind_of(Enumerable::Lazy) }
    end
    context "when no block is given" do
      subject { lazy_range.map }
      it "should return a lazy enumerable encapsulating Enumerable#map" do
        subject.take(10).should == [*0..9]
      end
      it { should be_kind_of(Enumerable::Lazy) }
    end
  end

  describe "#flat_map" do
    context "when a block is given" do
      subject { [[1,2], [5,6]].cycle.lazy.flat_map {|x| x + 2 } }

      it { should be_kind_of(Enumerable::Lazy) }
      it "should return an enumerable which maps over the flattened decoratee results" do
        subject.take(7).should == [3, 4, 7, 8, 3, 4, 7]
      end
    end
    context "when no block is given" do
      subject { lazy_range.flat_map}
      it "should return a lazy enumerable encapsulating Enumerable#flat_map"
      it { should be_kind_of(Enumerable::Lazy) }
    end
  end

  describe "#drop_while" do
    context "when a block is given" do
      subject { lazy_range.drop_while {|x| x < 3 } }

      it "should return an enumerable which excludes the fist elements that fullfils the condition" do
        subject.take(10).should == [*3..12]
      end
      it { should be_kind_of(Enumerable::Lazy) }
    end
    context "when no block is given" do
      subject { lazy_range.drop_while}
      it "should return a lazy enumerable encapsulating Enumerable#drop_while"
      it { should be_kind_of(Enumerable::Lazy) }
    end
  end

  describe "#take_while" do
    context "when a block is given" do
      subject { lazy_range.take_while {|x| x <= 3 } }

      it "should return an enumerable which only includes the fist elements that fullfils the condition" do
        subject.to_a == [*0..3]
      end
      it { should be_kind_of(Enumerable::Lazy) }
    end
    context "when no block is given" do
      subject { lazy_range.take_while }
      it "should return a lazy enumerable encapsulating Enumerable#take_while"
      it { should be_kind_of(Enumerable::Lazy) }
    end
  end

  describe "#drop" do
    subject { lazy_range.drop 5 }

    it "should return an enumerable which excludes the fist n elements" do
      subject.take(10).should == [*5..14]
    end
    it { should be_kind_of(Enumerable::Lazy) }
  end

  describe "#take" do
    it "should return an enumerable which only includes the fist n elements" do
      lazy_range.take(5).should == [*0..4]
    end
  end

  describe "#grep" do
    subject { lazy_range.grep(5..8) }

    context "when no block is given" do
      it { should be_kind_of(Enumerable::Lazy) }
      it "should return an enumerable which filters over the decoratee using the passed argument"
    end

    context "when a block is given"  do
      it "should iterate over the decorated enumerable"
      it "should return an array with the block's results"
    end
  end

  describe "#zip" do
    context "when no block is given" do
      subject { lazy_range.zip(15..18) }

      it { should be_kind_of(Enumerable::Lazy) }
      it "should return an enumerator which zips the decoratee results with the enumerables passed" do
        subject.take(6).should == [ [0,15], [1,16], [2,17], [3,18], [4,nil], [5,nil]]
      end
    end

    context "when a block is given" do
      let (:lazy_array) { [4,5].lazy }

      it { lazy_array.zip(10..22) {}.should be_nil }
      it "should iterate over the zipped results" do
        enum = [4,5].zip([10,11]).to_enum
        lazy_array.zip(10..22) {|arr| arr.should == enum.next }
      end
    end
  end


  describe "#slice_before" do
    subject { lazy_range.slice_before { x.even? } }

    it { should be_kind_of(Enumerable::Lazy) }
  end

  describe "#chunk" do
    subject { lazy_range.chunk { x.even? } }

    it { should be_kind_of(Enumerable::Lazy) }
  end


  describe "#cycle" do
    context "when a block is given" do
      let (:lazy_array) { [1].lazy }
      it "should cycle using the block" do
        mocked_block.should_receive(:call).with(1).twice
        lazy_array.cycle(2) {|n| mocked_block.call(n) }
      end

      it { lazy_array.cycle(1) {}.should be_nil }
    end

    context "when no block is given" do
      subject { (5..8).lazy.cycle }

      it { should be_kind_of(Enumerable::Lazy) }
      it "should cycle over the decorated enumerable elements" do
        subject.take(5).should == [5, 6 ,7, 8, 5]
      end
      it "should return an empty array if previous enumerator did not produce any result" do
        (0...0).lazy.cycle.to_a.should == []
      end
    end
  end
end

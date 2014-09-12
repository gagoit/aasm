require 'spec_helper'

describe 'transitions' do

  it 'should raise an exception when whiny' do
    process = ProcessWithNewDsl.new
    expect { process.stop! }.to raise_error(AASM::InvalidTransition)
    expect(process).to be_sleeping
  end

  it 'should not raise an exception when not whiny' do
    silencer = Silencer.new
    expect(silencer.smile!).to be_false
    expect(silencer).to be_silent
  end

  it 'should not raise an exception when superclass not whiny' do
    sub = SubClassing.new
    expect(sub.smile!).to be_false
    expect(sub).to be_silent
  end

  it 'should not raise an exception when from is nil even if whiny' do
    silencer = Silencer.new
    expect(silencer.smile_any!).to be_true
    expect(silencer).to be_smiling
  end

  it 'should call the block when success' do
    silencer = Silencer.new
    success = false
    expect {
      silencer.smile_any! do
        success = true
      end
    }.to change { success }.to(true)
  end

  it 'should not call the block when failure' do
    silencer = Silencer.new
    success = false
    expect {
      silencer.smile! do
        success = true
      end
    }.not_to change { success }.to(true)
  end

end

describe 'blocks' do
end

describe AASM::Transition do
  it 'should set from, to, and opts attr readers' do
    opts = {:from => 'foo', :to => 'bar', :guard => 'g'}
    st = AASM::Transition.new(opts)

    expect(st.from).to eq(opts[:from])
    expect(st.to).to eq(opts[:to])
    expect(st.opts).to eq(opts)
  end

  it 'should set on_transition with deprecation warning' do
    opts = {:from => 'foo', :to => 'bar'}
    st = AASM::Transition.allocate
    st.should_receive(:warn).with('[DEPRECATION] :on_transition is deprecated, use :after instead')

    st.send :initialize, opts do
      guard :gg
      on_transition :after_callback
    end

    st.opts[:after].should == [:after_callback]
  end

  it 'should set after and guard from dsl' do
    opts = {:from => 'foo', :to => 'bar', :guard => 'g'}
    st = AASM::Transition.new(opts) do
      guard :gg
      after :after_callback
    end

    st.opts[:guard].should == ['g', :gg]
    st.opts[:after].should == [:after_callback] # TODO fix this bad code coupling
  end

  it 'should pass equality check if from and to are the same' do
    opts = {:from => 'foo', :to => 'bar', :guard => 'g'}
    st = AASM::Transition.new(opts)

    obj = double('object')
    allow(obj).to receive(:from).and_return(opts[:from])
    allow(obj).to receive(:to).and_return(opts[:to])

    expect(st).to eq(obj)
  end

  it 'should fail equality check if from are not the same' do
    opts = {:from => 'foo', :to => 'bar', :guard => 'g'}
    st = AASM::Transition.new(opts)

    obj = double('object')
    allow(obj).to receive(:from).and_return('blah')
    allow(obj).to receive(:to).and_return(opts[:to])

    expect(st).not_to eq(obj)
  end

  it 'should fail equality check if to are not the same' do
    opts = {:from => 'foo', :to => 'bar', :guard => 'g'}
    st = AASM::Transition.new(opts)

    obj = double('object')
    allow(obj).to receive(:from).and_return(opts[:from])
    allow(obj).to receive(:to).and_return('blah')

    expect(st).not_to eq(obj)
  end
end

describe AASM::Transition, '- when performing guard checks' do
  it 'should return true of there is no guard' do
    opts = {:from => 'foo', :to => 'bar'}
    st = AASM::Transition.new(opts)

    expect(st.perform(nil)).to be_true
  end

  it 'should call the method on the object if guard is a symbol' do
    opts = {:from => 'foo', :to => 'bar', :guard => :test}
    st = AASM::Transition.new(opts)

    obj = double('object')
    expect(obj).to receive(:test)

    st.perform(obj)
  end

  it 'should call the method on the object if guard is a string' do
    opts = {:from => 'foo', :to => 'bar', :guard => 'test'}
    st = AASM::Transition.new(opts)

    obj = double('object')
    expect(obj).to receive(:test)

    st.perform(obj)
  end

  it 'should call the proc passing the object if the guard is a proc' do
    opts = {:from => 'foo', :to => 'bar', :guard => Proc.new { test }}
    st = AASM::Transition.new(opts)

    obj = double('object')
    expect(obj).to receive(:test)

    st.perform(obj)
  end
end

describe AASM::Transition, '- when executing the transition with a Proc' do
  it 'should call a Proc on the object with args' do
    opts = {:from => 'foo', :to => 'bar', :after => Proc.new {|a| test(a) }}
    st = AASM::Transition.new(opts)
    args = {:arg1 => '1', :arg2 => '2'}
    obj = double('object', :aasm => 'aasm')

    obj.should_receive(:test).with(args)

    st.execute(obj, args)
  end

  it 'should call a Proc on the object without args' do
    prc = Proc.new {||}
    opts = {:from => 'foo', :to => 'bar', :after => prc }
    st = AASM::Transition.new(opts)
    args = {:arg1 => '1', :arg2 => '2'}
    obj = double('object', :aasm => 'aasm')

    obj.should_receive(:instance_exec).with(no_args)  # FIXME bad spec

    st.execute(obj, args)
  end
end

describe AASM::Transition, '- when executing the transition with an :after method call' do
  it 'should accept a String for the method name' do
    opts = {:from => 'foo', :to => 'bar', :after => 'test'}
    st = AASM::Transition.new(opts)
    args = {:arg1 => '1', :arg2 => '2'}
    obj = double('object', :aasm => 'aasm')

    expect(obj).to receive(:test)

    st.execute(obj, args)
  end

  it 'should accept a Symbol for the method name' do
    opts = {:from => 'foo', :to => 'bar', :after => :test}
    st = AASM::Transition.new(opts)
    args = {:arg1 => '1', :arg2 => '2'}
    obj = double('object', :aasm => 'aasm')

    expect(obj).to receive(:test)

    st.execute(obj, args)
  end

  it 'should pass args if the target method accepts them' do
    opts = {:from => 'foo', :to => 'bar', :after => :test}
    st = AASM::Transition.new(opts)
    args = {:arg1 => '1', :arg2 => '2'}
    obj = double('object', :aasm => 'aasm')

    def obj.test(args)
      "arg1: #{args[:arg1]} arg2: #{args[:arg2]}"
    end

    return_value = st.execute(obj, args)

    expect(return_value).to eq('arg1: 1 arg2: 2')
  end

  it 'should NOT pass args if the target method does NOT accept them' do
    opts = {:from => 'foo', :to => 'bar', :after => :test}
    st = AASM::Transition.new(opts)
    args = {:arg1 => '1', :arg2 => '2'}
    obj = double('object', :aasm => 'aasm')

    def obj.test
      'success'
    end

    return_value = st.execute(obj, args)

    expect(return_value).to eq('success')
  end

  it 'should allow accessing the from_state and the to_state' do
    opts = {:from => 'foo', :to => 'bar', :after => :test}
    transition = AASM::Transition.new(opts)
    args = {:arg1 => '1', :arg2 => '2'}
    obj = double('object', :aasm => AASM::InstanceBase.new('object'))

    def obj.test(args)
      "from: #{aasm.from_state} to: #{aasm.to_state}"
    end

    return_value = transition.execute(obj, args)

    expect(return_value).to eq('from: foo to: bar')
  end

end

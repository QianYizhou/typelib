require 'set'
require 'test_config'
require 'typelib'
require 'test/unit'
require BUILDDIR + '/ruby/libtest_ruby'
require 'pp'

class TC_Value < Test::Unit::TestCase
    include Typelib
    def teardown
	GC.start
    end

    class CXXRegistry < Typelib::Registry
        def initialize
            super
            Typelib::Registry.add_standard_cxx_types(self)
        end
    end

    # Not in setup() since we want to make sure
    # that the registry is not destroyed by the GC
    def make_registry
        registry = Registry.new
        testfile = File.join(SRCDIR, "test_cimport.1")
        assert_raises(RuntimeError) { registry.import( testfile ) }
        registry.import( testfile, "c" )
        registry
    end

    def test_to_ruby
	int = CXXRegistry.new.get("/int").new
	int.zero!
	assert_equal(0, int.to_ruby)

	str = CXXRegistry.new.build("/char[20]").new
        20.times do |i|
            str[i] = ?a + i
        end
	assert_kind_of(String, str.to_ruby)
    end

    def test_value_init
        type = CXXRegistry.new.build("/int")
	value = type.new

	assert(ptr = value.instance_variable_get(:@ptr))
	assert_equal(value.zone_address, ptr.zone_address)
    end

    def test_wrap_argument_check
        registry = make_registry
        type = CXXRegistry.new.build("/int")

        assert_raises(ArgumentError) { type.wrap(nil) }
        assert_raises(ArgumentError) { type.wrap(10) }
    end

    def test_value_equality
        type = CXXRegistry.new.build("/int")
	v1 = type.new.zero!
	v2 = type.new.zero!
	assert_equal(0, v1)
	assert_equal(v1, v2)
	assert(! v1.eql?(v2))
	
	# This one is tricky: we want to have == return true if the fields of a
	# compounds are equal, regardless of padding bytes. So we prepare a
	# pattern which will be used as "blank" memory and then fill the fields
        registry = make_registry
        a_type    = registry.get("/A")
	a_pattern = (1..a_type.size).to_a.pack("c*")
	a1 = a_type.wrap a_pattern
	a2 = a_type.wrap a_pattern.reverse
	a1.a = a2.a = 10
	a1.b = a2.b = 20
	a1.c = a2.c = 30
	a1.d = a2.d = 40
	assert_equal(a1, a2)
	assert(! a1.eql?(a2))

	a2.d = 50
	assert_not_equal(a1, a2)

	assert_raises(ArgumentError) { a1 == v1 }
    end

    def test_value_cast
        r0 = make_registry
        r1 = make_registry
        t0 = r0.get 'StdCollections'
        t1 = r1.get 'StdCollections'

        v0 = t0.new
        assert_same v0, v0.cast(t0)
        v1 = v0.cast(t1)

        assert_not_same v0, v1
        assert(t0 == t1)

        wrong_type = r1.get 'A'
        assert_raises(ArgumentError) { v0.cast(wrong_type) }
    end

    def test_byte_array
	as_string = [5].pack('S')
	long_t = CXXRegistry.new.build("/short")

	assert_raises(ArgumentError) { long_t.wrap "" }
	rb_value = long_t.wrap as_string
	as_string = rb_value.to_byte_array
	assert_equal(2, as_string.size)
	assert_equal(5, as_string.unpack('S').first)

        a = make_registry.get('ADef')
        # The following line will lead to valgrind complaining. This is
        # harmless: we access the attribute values before we assign them.
        a = a.new :a => 10, :b => 20, :c => 30, :d => 40
	assert_equal([10, 20, 30, 40], a.to_byte_array.unpack('Qicxs'))
    end

    def test_pointer
        type = CXXRegistry.new.build("/int*")
	value = type.new
	value.zero!
        assert_raises(ArgumentError) { value.deference }
	assert(value.null?)
	assert_equal(nil, value.to_ruby)

        type  = CXXRegistry.new.build("/int")
        value = type.new
        assert_equal(value.class, type)
        ptr   = value.to_ptr
        assert_same(value, ptr.deference)
    end

    def test_string_handling
        buffer_t = CXXRegistry.new.build("/char[256]")
        buffer = buffer_t.new
	assert( buffer.string_handler? )
        assert( buffer.respond_to?(:to_str))

        # Check that .from_str.to_str is an identity
        typelib_value = Typelib.from_ruby("first test", buffer_t)
        assert_kind_of buffer_t, typelib_value
	assert_equal("first test", typelib_value.to_ruby)
        assert_raises(ArgumentError) { Typelib.from_ruby("a"*512, buffer_t) }
    end

    def test_pretty_printing
        b = make_registry.get("/B").new
        b.zero!
        assert_nothing_raised { pp b }
    end

    def test_to_csv
        klass = make_registry.get("/DisplayTest")
        assert_equal("t.fields[0] t.fields[1] t.fields[2] t.fields[3] t.f t.d t.a.a t.a.b t.a.c t.a.d t.mode", klass.to_csv('t'));
        assert_equal(".fields[0] .fields[1] .fields[2] .fields[3] .f .d .a.a .a.b .a.c .a.d .mode", klass.to_csv);
        assert_equal(".fields[0],.fields[1],.fields[2],.fields[3],.f,.d,.a.a,.a.b,.a.c,.a.d,.mode", klass.to_csv('', ','));

        value = klass.new
	value.zero!
        value.fields[0] = 0;
        value.fields[1] = 1;
        value.fields[2] = 2;
        value.fields[3] = 3;
        value.f = 1.1;
        value.d = 2.2;
        value.a.a = 10;
        value.a.b = 20;
        value.a.c = 'b';
        value.a.d = 42;

        space_sep = value.to_csv.split(" ")
        assert_in_delta(1.1, Float(space_sep[4]), 0.00001)
        assert_in_delta(2.2, Float(space_sep[5]), 0.00001)
        space_sep[4] = "1.1"
        space_sep[5] = "2.2"
        assert_equal("0 1 2 3 1.1 2.2 10 20 98 42 OUTPUT", space_sep.join(" "))

        comma_sep = value.to_csv(",").split(",")
        assert_in_delta(1.1, Float(space_sep[4]), 0.00001)
        assert_in_delta(2.2, Float(space_sep[5]), 0.00001)
        comma_sep[4] = "1.1"
        comma_sep[5] = "2.2"
        assert_equal("0,1,2,3,1.1,2.2,10,20,98,42,OUTPUT", comma_sep.join(","))
    end
	

    def test_is_a
        registry = make_registry
        a = registry.get("/A").new
	assert( a.is_a?("/A") )
	assert( a.is_a?(/A$/) )

	assert( a.is_a?(registry.get("/A")) )
	assert( a.is_a?(registry.get("long long")) )
    end

    def test_dup
        registry = make_registry
        a = registry.get("/A").new
	a.a = 20
	b = a.dup

	assert_kind_of(a.class, b)

	assert_equal(20, b.a)
	b.a = 10
	assert_equal(20, a.a)
	assert_equal(10, b.a)
    end

    def test_clone
        registry = make_registry
        a = registry.get("/A").new
	a.a = 20
	b = a.clone

	assert_kind_of(a.class, b)

	assert_equal(20, b.a)
	b.a = 10
	assert_equal(20, a.a)
	assert_equal(10, b.a)
    end


    def test_to_s
	int_value = CXXRegistry.new.get("/int").new
	int_value.zero!
	assert_equal("0", int_value.to_s)
    end

    def test_copy
        r0 = make_registry
        r1 = make_registry

        type0 = r0.get "/B"
        type1 = r1.get "/B"

        v0 = type0.new
        v1 = type1.new
        v0.zero!
        v1.zero!
        v0.a.a = 20
        v0.a.b = 60
        v0.a.c = 4
        v0.a.d = 30
        v0.x = 230
        assert !v1.memory_eql?(v0)
        Typelib.copy(v1, v0)
        assert(v1 == v0, "copy failed: memory is not equal")
    end

    def test_nan_handling
        registry = make_registry
        lib = Library.open('libtest_ruby.so', registry)
        wrapper = lib.find('generate_nand').
            returns(nil).returns('double*')
	assert_equal(1.0/0.0, wrapper.call);
        wrapper = lib.find('generate_nanf').
            returns(nil).returns('float*')
	assert_equal(1.0/0.0, wrapper.call);
    end

    def test_convertion_to_from_ruby
        Typelib.convert_to_ruby '/NS1/Test', Integer do |value|
            value.a
        end
        Typelib.convert_from_ruby Fixnum, '/NS1/Test' do |value, expected_type|
            result = expected_type.new
            result.a = value
            result
        end

        registry = make_registry
        ns1_test_t = registry.get('/NS1/Test')
        assert_equal Integer, ns1_test_t.convertion_to_ruby[0]
        vector_ns1_test_t = registry.get('/std/vector</NS1/Test>')
        assert_equal Array, vector_ns1_test_t.convertion_to_ruby[0]
        vector_vector_ns1_test_t = registry.get('/std/vector</std/vector</NS1/Test>>')
        assert_equal Array, vector_vector_ns1_test_t.convertion_to_ruby[0]

        containers_t = registry.get('Collections')
        containers = containers_t.new

        v_v_struct = containers.v_v_struct
        assert_kind_of Array, v_v_struct
        assert_same v_v_struct, containers.v_v_struct

        v_v_struct << [10]
        puts v_v_struct.inspect
        puts containers_t.v_v_struct.name
        assert_equal [], containers.raw_v_v_struct.to_ruby
        containers.apply_changes_from_converted_types
        assert_equal [[10]], containers.raw_v_v_struct.to_ruby
    end
end


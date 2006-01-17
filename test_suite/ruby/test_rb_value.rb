require 'test/unit'
require 'test_config'
require '.libs/test_rb_value'
require 'typelib'
require 'pp'

class TC_Value < Test::Unit::TestCase
    include Typelib

    
    # Not in setup() since we want to make sure
    # that the registry is not destroyed by the GC
    def make_registry
        registry = Registry.new
        testfile = File.join(SRCDIR, "test_cimport.1")
        assert_raises(RuntimeError) { registry.import( testfile  ) }
        registry.import( testfile, "c" )

        registry
    end

    def test_import
        registry = make_registry
        assert( registry.get("/struct A") )
        assert( registry.get("/ADef") )
    end

    def test_respond_to
        a = Value.new(nil, make_registry.get("/struct A"))
        GC.start
        check_respond_to_fields(a)
    end

    def check_respond_to_fields(a)
        GC.start
        assert( a.respond_to?("a") )
        assert( a.respond_to?("b") )
        assert( a.respond_to?("c") )
        assert( a.respond_to?("d") )
        assert( a.respond_to?("a=") )
        assert( a.respond_to?("b=") )
        assert( a.respond_to?("c=") )
        assert( a.respond_to?("d=") )
    end

    def test_get
        a = Value.new(nil, make_registry.get("/struct A"))
        GC.start
        a = set_struct_A_value(a)
        assert_equal(10, a.a)
        assert_equal(20, a.b)
        assert_equal(30, a.c)
        assert_equal(40, a.d)
    end

    def test_set
        a = Value.new(nil, make_registry.get("/struct A"))
        GC.start
        a.a = 1;
        a.b = 2;
        a.c = 3;
        a.d = 4;
        assert( check_struct_A_value(a) )
    end

    def test_recursive
        b = Value.new(nil, make_registry.get("/struct B"))
        GC.start
        assert(b.respond_to?(:a))
        assert(! b.respond_to?(:a=))
        check_respond_to_fields(b.a)

        set_struct_A_value(b.a)
        assert_equal(10, b.a.a)
        assert_equal(20, b.a.b)
        assert_equal(30, b.a.c)
        assert_equal(40, b.a.d)
    end

    def test_array_basics
        b = Value.new(nil, make_registry.get("/struct B"))
        GC.start
        assert(b.respond_to?(:c))
        assert(! b.respond_to?(:c=))
        assert(b.c.is_a?(Typelib::Array))
        assert_equal(100, b.c.size)
    end
    def test_array_set
        b = Value.new(nil, make_registry.get("/struct B"))
        (0..(b.c.size - 1)).each do |i|
            b.c[i] = Float(i)/10.0
        end
        check_B_c_value(b)
    end
    def test_array_get
        b = Value.new(nil, make_registry.get("/struct B"))
        set_B_c_value(b)
        (0..(b.c.size - 1)).each do |i|
            assert( ( b.c[i] - Float(i)/10.0 ).abs < 0.01 )
        end
    end
    def test_array_each
        b = Value.new(nil, make_registry.get("/struct B"))
        set_B_c_value(b)
        b.c.each_with_index do |v, i|
            assert( ( v - Float(i)/10.0 ).abs < 0.01 )
        end
    end

end

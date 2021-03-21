mutable struct Frequency
    type::DataType
    freq::Int
end

Base.isless(a::Frequency, b::Frequency) = isless(a.freq, b.freq)

function increment!(c::Frequency)
    c.freq += 1
end

struct DataTypeFrequencies
    d::Dict{Int, Frequency}
    DataTypeFrequencies() = new(Dict())
end

function increment!(tf::DataTypeFrequencies, t::DataType)
    f = get!(() -> Frequency(t, 0), tf.d, t.hash)
    increment!(f)
end

Base.values(tf::DataTypeFrequencies) = values(tf.d)
Base.empty!(tf::DataTypeFrequencies) = empty!(tf.d)

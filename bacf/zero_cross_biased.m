function x = zero_cross_biased(data, bias)
    x = logical((sign(data+bias)+1)/2);
end
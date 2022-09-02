function x = zero_cross_hyst(data, bias)
    x = logical(zeros(length(data),1));
    last_value = logical(0);
    for i = 1:length(data)
        if (not(last_value) & (data(i) >= bias))
            last_value = 1;
        elseif (last_value & (data(i) <= -bias))
            last_value = 0;
        end
        x(i) = last_value;
    end
end
function x = freq_est(data,fs)
    mins = 0;
    mid_val = max(data)/2;
    for i = 2:length(data)-1
        if(data(i) < data(i-1) && data(i) <= data(i+1) && data(i) < mid_val)
            mins(end+1) = i;
        end
    end
    %mins
    k = 2:length(mins);
    mins = mins(k)./(k-1);
    x = fs/mean(mins);
end
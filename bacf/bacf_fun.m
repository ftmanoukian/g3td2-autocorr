function x = bacf_fun(data, windowlen)
    if(length(data) < windowlen/32)
        disp('El tama?o de ventana solicitado es mayor que el disponible')
        x = -1; 
    else
        windowlen = floor(windowlen/2);
        vars_in_window = floor(windowlen/32);
        bacvec = uint32(zeros(windowlen, 1));
        for sample_shift = 1:windowlen
            for displace = 1:vars_in_window
                idx = ceil(sample_shift/32) - 1;
                bit_shift = mod(sample_shift-1,32);

                var1 = data(displace);
                var2 = bitor(bitshift(data(idx+displace),bit_shift),bitshift(data(idx+displace+1),bit_shift-32));

                bacvec(sample_shift) = bacvec(sample_shift) + sum(bitget(bitxor(var1,var2),1:32));
            end
        end
        
        x = bacvec;
    end
end
clear, clc;

[audio_array,fs] = audioread('pianoa2_mono.wav');

% El archivo de audio est? muestreado a frecuencia "fs". Como vamos a
% trabajar muestreando a frecuencia "new_fs", se resamplea audio_array a
% audio_array_rs. Esto es solo para adaptar los datos y no es parte del
% algoritmo.
new_fs = 100e3;
audio_array_rs = resample(audio_array,fs,new_fs);

% Simulaci?n de filtrado digital (post-muestreo, pre-procesamiento). 
% La idea de este filtro es reducir el ancho de banda con un corte
% pronunciado, para poder reducir la frecuencia de muestreo y trabajar con 
% menos datos (dentro del micro).
fc = 5e3;
[b,a] = butter(10,fc/(new_fs/2));

audio_array_filtered_rs = filter(b,a,audio_array_rs);

% Nueva frecuencia de muestreo (post-filtrado digital)
low_fs = 10e3;
audio_array_lowfs = resample(audio_array_filtered_rs,new_fs,low_fs);

% Como import? el archivo entero, rescato s?lo una fracci?n f?cilmente
% visible en un plot (esto no pasa adentro del micro).
import_disp = 1e3;
subgroup_audio_array = audio_array_lowfs(import_disp:import_disp+2e4);

% Cruces por cero - creo un vector booleano que almacena 1 si la se?al est?
% por encima de "-bias", y 0 si est? por debajo. En el micro, este paso y
% el siguiente est?n integrados en uno solo
% Hay dos funciones para calcular esto:
%   - zero_cross_biased devuelve 1 si "data(i)" est? por encima de "bias",
%       y 0 si est? por debajo
%   - zero_cross_hyst es similar pero con hist?resis "bias" por encima y
%       por debajo de 0. Es decir, si la muestra anterior devolvi? 0 la
%       actual debe cruzar "bias" por encima de 0 para devolver 1 (caso
%       contrario devuelve 0 nuevamente). A la vez, si la muestra anterior
%       devolvi? 1, la actual debe cruzar "bias" por debajo de 0 para
%       devolver 0. Esto es para evitar que cambios peque?os cerca del
%       valor central (ruido por ej.) produzcan cambios en la se?al de
%       cruces.
bias = 0.1;
%zerocross_bool = zero_cross_biased(subgroup_audio_array,bias);
zerocross_bool = zero_cross_hyst(subgroup_audio_array,bias);

subplot(311), plot(subgroup_audio_array), axis tight, title('Audio');
subplot(312), stem(zerocross_bool), axis tight, title('Cruces por cero');

% Creo un vector que va a almacenar los datos del vector anterior, pero en
% vez de variable a variable, bit a bit. Por esto utilizo la longitud del
% anterior dividida por 32 (ya que trabajo con palabras de 32 bits).
zclen = length(zerocross_bool);
zcvec = uint32(zeros(ceil(zclen/32),1));

for i = 1:length(zcvec)-2
    aux_int = uint32(0);
    for k = 1:32
        curr_sample = zerocross_bool((i-1)*32 + (33-k));
        aux_int = bitset(aux_int,k,curr_sample);
    end
    zcvec(i) = aux_int;
end

% ===============================
% AUTOCORRELACION   =D
% ===============================
% Reci?n ac? empieza el algoritmo. El ?nico par?metro que recibe (adem?s de
% los datos) es el ancho de ventana (cantidad de datos a superponer).
% Como para cada superposici?n se realiza un desplazamiento, al realizar
% una cantidad de desplazamientos igual al ancho de la ventana la ventana
% deja de superponerse consigo misma. Por este motivo, deben existir datos
% que abarquen un ancho de dos ventanas (por lo menos). O, en su defecto,
% la ventana no puede ser mayor que la mitad del total de los datos.
windowlen = 8e3;
vars_in_window = floor(windowlen/32);
bacvec = uint32(zeros(windowlen, 1));

% Itero para cada desplazamiento (cada ?ndice si se quiere)
for sample_shift = 1:windowlen
    % Como s?lo puedo operar con 32 bits por vez, opero con la cantidad de
    % palabras necesarias para completar una ventana (tama?o_ventana/32)
    for displace = 1:vars_in_window
        idx = ceil(sample_shift/32);
        bit_shift = mod(sample_shift-1,32);

        % var1 tiene el set de datos sin desplazar
        % var2 tiene el set de datos desplazado. Como al desplazar se
        % "pierden" bits (que en realidad est?n en la variable siguiente
        % del array) desplazo ambas la cantidad necesaria y las superpongo.
        var1 = zcvec(displace);
        var2 = bitor(bitshift(zcvec(idx+displace),bit_shift),bitshift(zcvec(idx+displace+1),bit_shift-32));

        % Sumo al ?ndice actual del resultado la cantidad de bits en 1
        bacvec(sample_shift) = bacvec(sample_shift) + sum(bitget(bitxor(var1,var2),1:32));
    end
end

% Relleno el vector de resultado con ceros para poder graficarlo jutno con
% los de audio y cruces por cero
bacvec = [bacvec;zeros(length(subgroup_audio_array)-length(bacvec),1)];

subplot(313),plot(bacvec),axis tight, title('Autocorrelaci?n de cruces por cero');
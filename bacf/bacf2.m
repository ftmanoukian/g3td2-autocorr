clear, clc;

%[audio_array,fs] = audioread('pianoa5_mono.wav');
fs = 44100;
t = 0:1/fs:2;
audio_array = sin(2*pi*t*4200);
plot(t,audio_array);
audio_array = audio_array/max(audio_array); 

% El archivo de audio est? muestreado a frecuencia "fs". Como vamos a
% trabajar muestreando a frecuencia "new_fs", se resamplea audio_array a
% audio_array_rs. Esto es solo para adaptar los datos y no es parte del
% algoritmo.
new_fs = 100e3;
audio_array_rs = resample(audio_array,new_fs,fs);

% Simulaci?n de filtrado digital (post-muestreo, pre-procesamiento). 
% La idea de este filtro es reducir el ancho de banda con un corte
% pronunciado, para poder reducir la frecuencia de muestreo y trabajar con 
% menos datos (dentro del micro).
fc = 5e3;
[b,a] = butter(10,fc/(new_fs/2));

audio_array_filtered_rs = filter(b,a,audio_array_rs);

% Nueva frecuencia de muestreo (post-filtrado digital)
low_fs = 10e3;
audio_array_lowfs = resample(audio_array_filtered_rs,low_fs,new_fs);

%figure(2);
%subplot(311),plot(audio_array);
%subplot(312),plot(audio_array_filtered_rs);
%subplot(313),plot(audio_array_lowfs);

% Como import? el archivo entero, rescato s?lo una fracci?n f?cilmente
% visible en un plot (esto no pasa adentro del micro).
import_disp = 769;
subgroup_audio_array = audio_array_lowfs(import_disp:import_disp+3e3);

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

figure(1);
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

% Calculo "count" autocorrelaciones, con resoluci?n temporal (separaci?n de
% inicios) "sample_res" y calculo la frecuencia para cada una.

windowlen = 512;
sample_res = 128;
count = 20;
freqs = zeros(1,length(zerocross_bool));
for i = 1:count
    short_idx = fix(1+(i-1)*sample_res/32);
    bacf_aux = bacf_fun(zcvec(short_idx:end),windowlen);
    freq_aux = freq_est(bacf_aux,low_fs);
    freqs(1+(i-1)*sample_res:i*sample_res) = freq_aux;
end
subplot(313),plot(freqs),title('Frecuencia Estimada [Hz]');
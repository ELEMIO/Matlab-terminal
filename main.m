%% Terminal with filters
% Terminal with filters for visualization signal from ELEMIO sensor (version for Arduino)
% 2018-04-18 by ELEMIO (https://github.com/eadf)
% 
% Changelog:
%     2018-04-18 - initial release

%% Code is placed under the MIT license
% Copyright (c) 2018 ELEMIO
% 
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
% 
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
% 
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
% THE SOFTWARE.
% ===============================================

%% Delete old variables
clearvars;
delete(instrfindall);

%% Main graphics window
Graphics % File with visual data
Handles = guihandles(Fig); % Find graphics elements

%% Variables for communication
COM = 'COM23'; % COM port of Arduino
BaudRate = 115200; % Baudrate of communication

%% Variables
l = 2; % Index of the data point
Data = zeros(1, 2); % Array of data points
v = 0; % Value from COM port
offset = 0; % Graph offset

%% Start the serial communication
s = serial(COM,'BaudRate',BaudRate);
fopen(s);

%% Sample time
dt = 1e-3;

%% Gain
gain = 1;

%% Initial state of filter
% Sample frequency
Sample_freq = 1 / dt;
% Bandpass
W1_pass = 30;
W2_pass = 70;
order_pass = 3;
[b_pass,a_pass] = butter(order_pass, [W1_pass / (Sample_freq / 2), W2_pass / (Sample_freq / 2)], 'bandpass');
% Bandstop
W1_stop = 45;
W2_stop = 55;
order_stop = 2;
[b_stop,a_stop] = butter(order_stop, [W1_stop / (Sample_freq / 2), W2_stop / (Sample_freq / 2)], 'stop');

%% Main loop
while(ishandle(1))  % While exists figure
    if (s.BytesAvailable >= 12) % At least 3 points exist in the buffer
        %% Read data from serial buffer
        data = char(fread(s, s.BytesAvailable)); % Read raw data from serial buffer
        v = sscanf(data,'%d'); % Convert raw data to array   
        if (length(v) < 3)% If some troubles
        	v = [0; 0; 0]; 
        end
        v(1) = v(2);
        v(length(v)) = v(length(v)-1); % Delete extreme points that may not be complete
        
        %% Append new data
        t = zeros(length(v),2);
        t(:, 1) = v;
        t(1, 2) = Data(l-1,2) + dt;
        for i = 2:length(v)
            t(i, 2) = t(i-1, 2) + dt;
        end
        Data(l:l+length(v)-1,:) = t;
        
        %% Shift the boundaries of the graph
        T = Data(l+length(v)-1,2); % Curent time
        if Handles.full.Value == 1 % If "Full time" option
            set(Handles.main_axes, 'XLim', [0 T+0.1]);
        end
        if Handles.section.Value == 1 % If "10s section" option
            right = Handles.main_axes.XLim(2);
            if T > right
              set(Handles.main_axes, 'XLim', [right right+10]);
            end
        end
        
        %% Update gain
        old_gain = gain; % Remember old value of the gain
        gain = Handles.gainx1.Value * 1 + ...
            Handles.gainx2.Value * 2 + ...
            Handles.gainx4.Value * 4 + ...
            Handles.gainx5.Value * 5 + ...
            Handles.gainx8.Value * 8 + ...
            Handles.gainx10.Value * 10 + ...
            Handles.gainx16.Value * 16 + ...
            Handles.gainx32.Value * 32; % Read gain
        if (old_gain ~= gain) % If gain updated
            fwrite(s, gain); % Write gain to Arduino
        end
        
        %% Filtering signal
        % Update values
        dt = str2double( Handles.Period.String ) * 1e-3;
        Sample_freq = 1 / dt;
        W1_pass = str2double( Handles.W1_pass.String );
        W1_stop = str2double( Handles.W1_stop.String );
        W2_pass = str2double( Handles.W2_pass.String );
        W2_stop = str2double( Handles.W2_stop.String );
        offset = str2double( Handles.Offset.String );
        % Bandpass filter
        if (Handles.Bandpass.Value == 1) && (Handles.Bandstop.Value == 0)
            [b_pass,a_pass] = butter(order_pass, [W1_pass / (Sample_freq / 2), W2_pass / (Sample_freq / 2)], 'bandpass');
            Data_filtered(1:l,1) = filtfilt(b_pass, a_pass, Data(1:l,1));
        end
        % Bandpass filter
        if (Handles.Bandpass.Value == 0) && (Handles.Bandstop.Value == 1)
            [b_stop,a_stop] = butter(order_stop, [W1_stop / (Sample_freq / 2), W2_stop / (Sample_freq / 2)], 'stop');
            Data_filtered(1:l,1) = filtfilt(b_stop, a_stop, Data(1:l,1));
        end
        % Bandpass filter and bandpass filter
        if (Handles.Bandpass.Value == 1) && (Handles.Bandstop.Value == 1)
            [b_pass,a_pass] = butter(order_pass, [W1_pass / (Sample_freq / 2), W2_pass / (Sample_freq / 2)], 'bandpass');
            [b_stop,a_stop] = butter(order_stop, [W1_stop / (Sample_freq / 2), W2_stop / (Sample_freq / 2)], 'stop');
            Data_temp(1:l,1) = filtfilt(b_pass, a_pass, Data(1:l,1));
            Data_filtered(1:l,1) = filtfilt(b_stop, a_stop, Data_temp(1:l,1));
        end
        % No filters
        if (Handles.Bandpass.Value == 0) && (Handles.Bandstop.Value == 0)
            Data_filtered(1:l,1) = Data(1:l,1);
        end
        
        %% Update plot data
        set(MyoData, 'XData', Data(1:l,2), 'YData',  Data_filtered(1:l,1) + offset);
        pause(0.05);
        
        l = l + length(v); % Update data index   
    end
end

%% Stop the serial communication
fclose(s);
classdef NKTControl < handle
    %NKTControl Class to control super continuum (SuperK) lasers from NKT.
    %
    % This class uses the serial communication (virtually through a USB
    % connection) to communicate with NKT SuperK Extreme products and may
    % potentially work for similar systems as well. All code is tested on 
    % a SuperK Extreme EXU-6.
    %Can obtain and change the power level and upper/lower bandwidths, turn
    %emission on or off, and reset the interlock.
    %
    %Methods:
    % * connect/disconnect - need to connect before use
    % * emissionOn/emissionOff
    % * resetInterlock
    % * getStatus - get status of the laser
    % * getVariaStatus - get status of Varia filter (optional)
    % * getPowerLevel/setPowerLevel - obtain/change power level in % with 0.1% precision 
    % * getUpperBandwidth/setUpperBandwidth - For Varia. Input in nm with 0.1nm precision
    % * getLowerBandwidth/setLowerBandwidth - Similar as above.
    % * getTimeout/setTimeout - Obtain/change timeout for serial port communucation
    %
    % Todo:
    % * Make all to disp-status commands "disablable"!
    % * addrLaser, addrVaria and host are at the moment hardcoded and hidden to the user
    % * make documentation nicer (type docNKTControl)
	 % * https://uk.mathworks.com/help/matlab/matlab_prog/add-help-for-your-program.html
    %
    % Examples:
    %   to come
    %
    % Authors: Jess Rigley and Villads Egede Johansen (University of Cambridge)
    % Contact: vej22@cam.ac.uk
    % Webpage: http://www.ch.cam.ac.uk/group/vignolini
    % Git repo: https://github.com/villadsegede/NKTcontrol.git
    % Version: 1.0
    % Date: 21/08-2017
    % Copyright: MIT License (see github page)
    
    properties
     timeout=0.05; %Timeout in seconds for the serial port.   
    end
    properties (Access=private)  
        s;      %Serial communication object.
    end
    
    methods 
    %Public methods
        function [] = connect(obj)
            % connect Connects to the laser.
            %
            % Detects which serial ports are available and tries to connect
            % to each in turn until the laser is connected. Always first
            % method to be called.
            %
            % see also: disconnect
            
            warning off MATLAB:serial:fread:unsuccessfulRead;
            %Find serial ports
            serialInfo = instrhwinfo('serial');
            ports=serialInfo.AvailableSerialPorts;
            for n=1:length(ports)
                obj.s=serial(ports(n),'BaudRate',115200,'Timeout',obj.timeout);
                fopen(obj.s);
                data='30';
                % Send telegram to laser and see if it replies.
                %If there is a reply starting with '0A' the laser is connected.
                obj.sendTelegram(obj.addrLaser,obj.msgRead,data);
                out=dec2hex(fread(obj.s,9),2);
                if isempty(out)==1
                    fclose(obj.s);
                    delete(obj.s);
                    clear obj.s
                    continue
                elseif out(1,:)==obj.startTel
                    disp('Laser connected');
                    break
                else
                    fclose(obj.s);
                    delete(obj.s);
                    clear obj.s
                    continue
                end
            end
            warning on MATLAB:serial:fread:unsuccessfulRead
        end
        
        
        function [] = disconnect(obj)
            % disconnect Close serial port connection thus disconnecting
            % laser.
            %
            % see also: connect
            
            fclose(obj.s);
            delete(obj.s);
            clear obj.s
            disp('Laser disconnected');
        end
        
        
        function [] = setTimeout(obj,timeout)
            %setTimeout Sets the timeout for the serial port in seconds.
            %
            % This function may be useful to play around with if either
            % communication fails or faster updates are required.
            % Input:
            %  timeout timeout value given in second.
            %
            % see also: getTimeout

            
            obj.timeout=timeout;            
        end
        
        
        function timeout = getTimeout(obj)
            %getTimeout Obtains the timeout for the serial port in seconds.
            %
            % Return:
            %  timeout Current timeout value given in seconds.
            %
            % see also: setTimeout
            
            timeout=obj.timeout;
        end
        
        
        function output = getStatus(obj)
            %getStatus Obtains the status of the laser.
            %
            % Checks whether the serial port is open, whether emission is on
            % or off, and whether the interlock needs resetting. Also gives
            % a notification when the clock battery is low.
            % 
            % Return:
            %   output  Status given as [emission,interlock,battery].
            %            Emission 0/1 is off/on; 
            %            Interlock 0/1 is on/off; 
            %            Battery 0/1 is okay/low.
            
            data='66';
            obj.sendTelegram(obj.addrLaser,obj.msgRead,data);
            out=obj.getTelegram(10);
            hexdata=[out(7,:) out(6,:)];
            decdata=hex2dec(hexdata);
            status=[dec2bin(decdata,16)];
            output=[status(16), status(15), status(9)];
            disp(['Com port ' obj.s.status]);
            if status(16)=='1'
                disp('Emission on');
            else disp('Emission off');
            end
            if status(15)=='0'
                disp('Interlock on');
            else disp('Interlock needs resetting');
            end
            if status(9)=='1' 
                disp('Clock battery voltage low');
            end
        end

        
        function output = getVariaStatus(obj)
            % getVariaStatus Obtains the status of the Varia filter. 
            %
            % Checks whether each shutter is open or closed and whether any
            % of the filters are moving.
            %
            % Return:
            %  output  Given as [Shutter 1, Shutter 2, Filter 1, Filter 2, Filter 3]
            %           Shutters 0/1 is closed/open; 
            %           filters 0/1 is stationary/moving.
            
            data='66';
            obj.sendTelegram(obj.addrVaria,obj.msgRead,data);
            out=obj.getTelegram(10);
            hexdata=[out(7,:) out(6,:)];
            decdata=hex2dec(hexdata);
            status=[dec2bin(decdata,16)];
            output=[status(8),status(7),status(4),status(3),status(2)];
            if status(8)=='1' 
                disp('Shutter 1 open');
            else disp('Shutter 1 closed');
            end
            if status(7)=='1' 
                disp('Shutter 2 open');
            else disp('Shutter 2 closed');
            end
            if status(4)=='1' 
                disp('Filter 1 moving');
            end
            if status(3)=='1' 
                disp('Filter 2 moving');
            end
            if status(2)=='1' 
                disp('Filter 3 moving');
            end
        end
           
        
        function [] = resetInterlock(obj)
            %resetInterlock Resets the interlock circuit.
            
            data=['32'; '01'];
            obj.sendTelegram(obj.addrLaser,obj.msgWrite,data);  
            obj.getTelegram(8);
        end
        
        
        function [] = emissionOn(obj)
            % emissionOn Turns emission on.
            %
            % see also: emissionOff
            
            data=['30'; '03'];
            obj.sendTelegram(obj.addrLaser,obj.msgWrite,data);
            obj.getTelegram(8);
        end
        
        function [] = emissionOff(obj)
            % emissionOff Turns emission off.
            %
            % see also: emissionOn
            
            data=['30'; '00'];
            obj.sendTelegram(obj.addrLaser,obj.msgWrite,data);
            obj.getTelegram(8);
        end
        
        function powerLevel = getPowerLevel(obj)
            % getPowerLevel Obtain power level
            %
            % Return:
            %   powerLevel  Power level given in percent with 0.1%
            %   precision
            %
            % see also: setPowerLevel
            
            data='37';
            obj.sendTelegram(obj.addrLaser,obj.msgRead,data);
            out=obj.getTelegram(10);
            %obtain hex power level from telegram
            hexPowerLevel=[out(7,:) out(6,:)];
            powerLevel=0.1*hex2dec(hexPowerLevel);%convert units to percent
        end
        
        
        function [] = setPowerLevel(obj,powerLevel)
            % setPowerLevel Set power level
            %
            % Input:
            %   powerLevel  Desired power level given in percentage with 0.1% precision
            %
            % see also: getPowerLevel

            powerLevel2=10*powerLevel; %convert units to 0.1%
            %convert power level to two bytes
            hexPowerLevel=dec2hex(powerLevel2,4);
            hexPowerLevel1=hexPowerLevel(1:2);
            hexPowerLevel2=hexPowerLevel(3:4);        
            data=['37'; hexPowerLevel2; hexPowerLevel1];
            obj.sendTelegram(obj.addrLaser,obj.msgWrite,data);
            obj.getTelegram(8);
        end

        
        function lowerBandwidth = getLowerBandwidth(obj)
            % getLowerBandwidth Get current lower bandwidth setting of Varia
            %
            % Return:
            %   lowerBandwidth   Lower band edge of the current filter setting
            %                    of the Varia filter given in nm specified
            %                    with 0.1nm precision.
            %
            % seeAlso: setLowerBandwidth, getUpperBandwidth, setUpperBandwidth

            data='34';
            obj.sendTelegram(obj.addrVaria,obj.msgRead,data);
            out=obj.getTelegram(10);
            %obtain hex bandwidth from telegram and convert to nm
            hexLowerBandwidth=[out(7,:) out(6,:)];
            lowerBandwidth=0.1*hex2dec(hexLowerBandwidth);
        end

        
        function [] = setLowerBandwidth(obj,lowerBandwidth)
            % setLowerBandwidth Set desired lower bandwidth setting of Varia
            %
            % Input:
            %   lowerBandwidth   Lower band edge to be set on the Varia 
            %                    filter given in nm specified with 0.1nm 
            %                    0.1nm precision.
            %
            % seeAlso: getLowerBandwidth, getUpperBandwidth, setUpperBandwidth            

            
            lowerBandwidth2=10*lowerBandwidth; %units 0.1nm
            %convert bandwidth to two bytes
            hexLowerBandwidth=dec2hex(lowerBandwidth2,4);
            hexLowerBandwidth1=hexLowerBandwidth(1:2);
            hexLowerBandwidth2=hexLowerBandwidth(3:4);
            data=['34'; hexLowerBandwidth2; hexLowerBandwidth1];
            obj.sendTelegram(obj.addrVaria,obj.msgWrite,data);
            obj.getTelegram(8);
        end
        
        
        function upperBandwidth = getUpperBandwidth(obj)
            % getUpperBandwidth Get current upper bandwidth setting of Varia
            %
            % Return:
            %   upperBandwidth   Upper band edge of the current filter setting
            %                    of the Varia filter given in nm specified
            %                    with 0.1nm precision.
            %
            % seeAlso: setLowerBandwidth, getLowerBandwidth, setUpperBandwidth

            data='33';
            obj.sendTelegram(obj.addrVaria,obj.msgRead,data);
            out=obj.getTelegram(10);
            %obtain hex upper bandwidth and convert to nm
            hexUpperBandwidth=[out(7,:) out(6,:)];
            upperBandwidth=0.1*hex2dec(hexUpperBandwidth);
        end
        
        
        function [] = setUpperBandwidth(obj,upperBandwidth)
            % setUpperBandwidth Set desired upper bandwidth setting of Varia
            %
            % Input:
            %   upperBandwidth   Upper band edge to be set on the Varia 
            %                    filter given in nm specified with 0.1nm 
            %                    0.1nm precision.
            %
            % seeAlso: getLowerBandwidth, setLowerBandwitdh, getUpperBandwidth

            upperBandwidth2=10*upperBandwidth; %units 0.1nm
            %convert to two bytes
            hexUpperBandwidth=dec2hex(upperBandwidth2,4);
            hexUpperBandwidth1=hexUpperBandwidth(1:2);
            hexUpperBandwidth2=hexUpperBandwidth(3:4);
            data=['33'; hexUpperBandwidth2; hexUpperBandwidth1];
            obj.sendTelegram(obj.addrVaria,obj.msgWrite,data);
            obj.getTelegram(8);
        end
    end
    
        
    % Private methods
    methods(Access=private)
        function [] = sendTelegram(obj,address,msgType,data)
            % sendTelegram sends a telegram to the laser
            %
            % Info on communication protocol to be found in documentation
            % for SuperK laser.
            %
            % Input:
            %  address  Address of the laser (16 bit)
            %  msgType  Type of message (16 bit)
            %  data     Data - if applicable
            %
            %(once again, see NKT SuperK documentation for details!)
            %
            % seeAlso: getTelegram
            
            message=[address; obj.host; msgType; data];
            crc=obj.crcValue(message);
            crc1=crc(1:2);
            crc2=crc(3:4);
            t=[obj.startTel; address; obj.host; msgType; data; crc1; crc2; obj.endTel];
            out(1,:)=obj.startTel;%start of transmission
            %replace special characters. m counts number of special
            %characters as this shifts subsequent rows of the array            
            m=0;
            for n=2:(length(t)-1)
                if t(n,:)=='0A'
                    out(n+m:n+m+1,:)=['5E'; '4A'];
                    m=m+1;
                elseif t(n,:)=='0D'
                    out(n+m:n+m+1,:)=['5E'; '4D'];
                    m=m+1;
                elseif t(n,:)=='5E'
                    out(n+m:n+m+1,:)=['5E'; '9E'];
                    m=m+1;
                else out(n+m,:)=t(n,:);
                end
            end
            out(length(out)+1,:)=obj.endTel;%end of transmission
            fwrite(obj.s,hex2dec(out),'uint8'); %send to laser
        end
        
        
        function out = getTelegram(obj,size)
            %getTelegram Receives a telegram from the laser.
            %
            % Info on communication protocol to be found in documentation
            % for SuperK laser.
            %
            % Input:
            %  Size  The expected length of the received telegram.
            %
            % seeAlso sendTelegram
            
            received=fread(obj.s,size);
            %replace any special characters in the telegram. m counts the number of special
            %characters as this shifts the subsequent rows of the array
            t=dec2hex(received,2);%telegram in hexadecimal
            m=0;
            n=1;
            while n<=length(t)
                if t(n,:)=='5E'
                    if t(n+1,:)=='4A'
                        out(n-m,:)='0A';
                    elseif t(n+1,:)=='4D'
                        out(n-m,:)='0D';
                    elseif t(n+1,:)=='9E'
                        out(n-m,:)='5E';
                    end
                    m=m+1;
                    n=n+2;
                else out(n-m,:)=t(n,:);
                    n=n+1;
                end
            end
            %check if transmission is complete and receive any additional
            %bytes if necessary 
            while out(length(out),:)~=obj.endTel 
                out(length(out)+1,:)=dec2hex(fread(obj.s,1),2);
            end
        end 
        
        function crc = crcValue(obj,message)
            %crcValue Finds the CRC value of a given message
            %
            % Info on communication protocol to be found in documentation
            % for SuperK laser. CRC value found through look-up table.
            %
            % Input:
            %  message  Data for which CRC value needs to be found.
            %
            % Return:
            %  crc  The corresponding CRC value.
            %  
            % seeAlso: sendTelegram
            
            data=hex2dec(message);
            
            ui16RetCRC16 = hex2dec('0');
            for I=1:length(data)
                ui8LookupTableIndex = bitxor(data(I),uint8(bitshift(ui16RetCRC16,-8)));
                ui16RetCRC16 = bitxor(obj.Crc_ui16LookupTable(double(ui8LookupTableIndex)+1),mod(bitshift(ui16RetCRC16,8),65536));
            end
            crc=dec2hex(ui16RetCRC16,4);
        end
    end

    
  properties(Constant, Access=private)
     %Bytes for the start and end of telegrams and the addresses of the
     %laser, varia, and host.
     
     %Start of telegram
     startTel='0D';
     %End of telegram
     endTel='0A';
     %Laser address
     addrLaser='0F';
     %Varia address: value of address switch on varia +10
     addrVaria='10';
     %Host Host address: can be anything greater than 160 (A0)
     host='A2';
     %Message type = read
     msgRead='04';
     %Message type = write
     msgWrite='05';
%CRC look up table
    Crc_ui16LookupTable=[0,4129,8258,12387,16516,20645,24774,28903,33032,37161,41290,45419,49548,...
    53677,57806,61935,4657,528,12915,8786,21173,17044,29431,25302,37689,33560,45947,41818,54205,...
    50076,62463,58334,9314,13379,1056,5121,25830,29895,17572,21637,42346,46411,34088,38153,58862,...
    62927,50604,54669,13907,9842,5649,1584,30423,26358,22165,18100,46939,42874,38681,34616,63455,...
    59390,55197,51132,18628,22757,26758,30887,2112,6241,10242,14371,51660,55789,59790,63919,35144,...
    39273,43274,47403,23285,19156,31415,27286,6769,2640,14899,10770,56317,52188,64447,60318,39801,...
    35672,47931,43802,27814,31879,19684,23749,11298,15363,3168,7233,60846,64911,52716,56781,44330,...
    48395,36200,40265,32407,28342,24277,20212,15891,11826,7761,3696,65439,61374,57309,53244,48923,...
    44858,40793,36728,37256,33193,45514,41451,53516,49453,61774,57711,4224,161,12482,8419,20484,...
    16421,28742,24679,33721,37784,41979,46042,49981,54044,58239,62302,689,4752,8947,13010,16949,...
    21012,25207,29270,46570,42443,38312,34185,62830,58703,54572,50445,13538,9411,5280,1153,29798,...
    25671,21540,17413,42971,47098,34713,38840,59231,63358,50973,55100,9939,14066,1681,5808,26199,...
    30326,17941,22068,55628,51565,63758,59695,39368,35305,47498,43435,22596,18533,30726,26663,6336,...
    2273,14466,10403,52093,56156,60223,64286,35833,39896,43963,48026,19061,23124,27191,31254,2801,6864,...
    10931,14994,64814,60687,56684,52557,48554,44427,40424,36297,31782,27655,23652,19525,15522,11395,...
    7392,3265,61215,65342,53085,57212,44955,49082,36825,40952,28183,32310,20053,24180,11923,16050,3793,7920];
       
  end     
end

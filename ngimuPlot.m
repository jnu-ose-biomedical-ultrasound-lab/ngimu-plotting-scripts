
%--------------------------------------------------------------------------
 % ngimuPlot.m

 % Last updated: March 2019, John LaRocco and Min Soohong
 
 % Jeju National University-Biomedical Ultrasound Lab
 
 % Details: This file loads up data from an NGIMU sensor, and can be run in
 % for either real time or archived data. 
 % Dependencies: This file requires the following scripts to interface with the device: 
 % Default scripts: udp and hsv
 % SixDofAnimation.m
 % importSession.m
 % resampleSession.m
 
%--------------------------------------------------------------------------


clc
clear
close all;

%% Use real time data: Comment out if not in use
%udpObject = udp('192.168.1.3', 'Localport', 8001,'InputBufferSize', 1472)
%fopen(udpObject);


%% Use archived data: Comment out if not in use
%sessionData = importSession('LOG_0016');
sessionData = importSession('LOG_0008');


samplePeriod = 1 / 50; % 400 H
[sessionData, time] = resampleSession(sessionData, samplePeriod); % resample data so each measurement type has the saem time vector
quaternion = sessionData.(sessionData.deviceNames{1}).quaternion.vector;
% acceleration = sessionData.(sessionData.deviceNames{1}).sensors.accelerometerVector * 9.81; % convert to m/s/s
acceleration = sessionData.(sessionData.deviceNames{1}).sensors.accelerometerVector; % convert to m/s/s
numberOfSamples = length(time);

%% Identify stationary periods

threshold = 1; % acceleration threshold in m/s/s

% Determine as moving if acceleration greater than theshold
isMoving = abs(acceleration(:,1)) > threshold | ...
           abs(acceleration(:,2)) > threshold | ...
           abs(acceleration(:,3)) > threshold;

% Add margin to extend each period identified as moving
marginSizeInSamples = ceil(0.1 / samplePeriod); % margin = 0.1 seconds
isMovingWithMargin = isMoving;
for sampleIndex = 1 : (numberOfSamples - marginSizeInSamples)
    if(isMoving(sampleIndex) == 1)
        isMovingWithMargin(sampleIndex : (sampleIndex + marginSizeInSamples)) = 1;
    end
end
% for sampleIndex = (numberOfSamples - marginSizeInSamples) : -1 : 1
for sampleIndex = (numberOfSamples - marginSizeInSamples) : 1
    if(isMoving(sampleIndex) == 1)
        isMovingWithMargin((sampleIndex - marginSizeInSamples) : sampleIndex) = 1;
    end
end

% Stationary periods are non-moving periods
isStationary = ~isMovingWithMargin;


%% Velocity calculation 

velocity = zeros(size(acceleration));
for sampleIndex = 2 : numberOfSamples
    velocity(sampleIndex, :) = velocity(sampleIndex - 1, :) + acceleration(sampleIndex, :) * samplePeriod;
    if(isStationary(sampleIndex) == 1)
        velocity(sampleIndex, :) = [0 0 0]; % force velocity to zero if stationary
    end
end

%% Velocity drift in each segment removed

stationaryStartIndexes = find([0; diff(isStationary)] == -1);
stationaryEndIndexes = find([0; diff(isStationary)] == 1);

velocityDrift = zeros(size(velocity));
for stationaryEndIndexesIndex = 1:numel(stationaryEndIndexes)

    velocityDriftAtEndOfMovement = velocity(stationaryEndIndexes(stationaryEndIndexesIndex) - 1, :);
    numberOfSamplesDuringMovement = (stationaryEndIndexes(stationaryEndIndexesIndex) - stationaryStartIndexes(stationaryEndIndexesIndex));
    velocityDriftPerSample = velocityDriftAtEndOfMovement / numberOfSamplesDuringMovement;

    ramp = (0 : (numberOfSamplesDuringMovement - 1))';
    velocityDriftDuringMovement = [ramp * velocityDriftPerSample(1), ...
                                   ramp * velocityDriftPerSample(2), ...
                                   ramp * velocityDriftPerSample(3)];

    velocityIndexes = stationaryStartIndexes(stationaryEndIndexesIndex):stationaryEndIndexes(stationaryEndIndexesIndex) - 1;
    velocity(velocityIndexes, :) = velocity(velocityIndexes, :) - velocityDriftDuringMovement;
end

%% Position calculation section

position = zeros(size(velocity));
for sampleIndex = 2 : numberOfSamples
    position(sampleIndex, :) = position(sampleIndex - 1, :) + velocity(sampleIndex, :) * samplePeriod;
end


%% Animation and replay of data

figure();
SixDofAnimation(position, quatern2rotMat(quaternion), ...
                'SamplePlotFreq', 1/samplePeriod, 'Trail', 'All', ...
                'Position', [9 39 1280 768], ...
                'AxisLength', 0.1, 'ShowArrowHead', false, ...
                'Xlabel', 'X (m)', 'Ylabel', 'Y (m)', 'Zlabel', 'Z (m)', 'ShowLegend', false);


%% Gyroscope data plot

deviceColours = hsv(sessionData.numberOfDevices);

figure;
for deviceIndex = 1:sessionData.numberOfDevices
    deviceName = sessionData.deviceNames{deviceIndex};
    deviceColour = deviceColours(deviceIndex, :);

    subplot(3,1,1);
    hold on;
    plot(time, sessionData.(deviceName).sensors.gyroscopeX, 'Color', deviceColour);
    title('Gyroscope X axis');
    xlabel('Time (s)');
    ylabel('deg/s');

    subplot(3,1,2);
    hold on;
    plot(time, sessionData.(deviceName).sensors.gyroscopeY, 'Color', deviceColour);
    title('Gyroscope Y axis');
    xlabel('Time (s)');
    ylabel('deg/s');

    subplot(3,1,3);
    hold on;
    plot(time, sessionData.(deviceName).sensors.gyroscopeZ, 'Color', deviceColour);
    title('Gyroscope Z axis');
    xlabel('Time (s)');
    ylabel('deg/s');
end
%% Create gyroscope plotting animation
figure();
X=sessionData.(deviceName).sensors.gyroscopeX;
Y=sessionData.(deviceName).sensors.gyroscopeY;
Z=sessionData.(deviceName).sensors.gyroscopeZ;
[x, y] = meshgrid(X, Y);
[z, ~]=meshgrid(Z,Z);
h = surf(x,y,z);
xlabel('x'); ylabel('y'); zlabel('z') 

% Rotate drawing horizontally
for a = -30 : 1 : 30
    view(a, 30)
    drawnow
end 

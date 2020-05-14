function [States] = FindingStateSpacePhysical(CaseName, Iterations, InitialFailures, LoadGenerationRatio, LoadShedConstant, EstimationError)
% Things added to this code
% 1- There is some fixed probability of failure for neighbors of failed lines
% 2- Failure prob corresponds to the amount of overload
% 3- Set the new load shed status to grid before run it again
%clc; close all;
define_constants;
%CaseName='case118'; %Function version uses given statename
%%% Parameter initialization
%TrueCaps=[20 80 200 500 800 9900]; % Zhuoyao
TrueCaps=[20 60 120 200 332 9900]; % PD
FakeCaps=TrueCaps;
NumIt = Iterations; % Number of iteration for extracting states..
% Load=5.0; % This means initial demands will be multiplied by Load [3.5-6.7]
FixedFailProb = 0.06; % some small prob of failure for neighbors of failed lines please assign it in this interval [0.01 0.2] not larger
% Initial load on which the capacity of lines will be determined
mpc1 = loadcase(CaseName);
mpc1 = ReadyTheCase(mpc1);
%%% keep the original values of number of buses and gens and branches before changing
originalNumBus=length(mpc1.bus(:,1));
originalNumGen=length(mpc1.gen(:,1));
originalNumBran=length(mpc1.branch(:,1));
%%% Seperate the buses with both load and generators into seperate load and
%%% generator buses
[mpc1 LoadGenMatch]=SeperateGenAndLoad(mpc1);
% In the case of IEEE 118 topology 6.9 corresponds to using the full generation capacity of the grid
[WhichInitialLoad, Generation, Demand, DemandIndex]=FindFullLoadOfGrid(mpc1);
clear mpc1;
% Run the power grid in the normal case to obtain the line capacities
% CapFinder function finds the power flow over the lines at the load
mpc1 = loadcase(CaseName);
mpc1 = ReadyTheCase(mpc1);
%%% keep the original values of number of buses and gens and branches before changing
originalNumBus=length(mpc1.bus(:,1));
originalNumGen=length(mpc1.gen(:,1));
originalNumBran=length(mpc1.branch(:,1));
%%% Seperate the buses with both load and generators into seperate load and
%%% generator buses
[mpc1 LoadGenMatch]=SeperateGenAndLoad(mpc1);
Capacity=CapFinder(WhichInitialLoad,mpc1,TrueCaps,FakeCaps,originalNumBran);
mpc1.branch(:,6)=Capacity;
CountCaps=zeros(1,length(TrueCaps));
for i=1:length(TrueCaps)
    CountCaps(i)=sum(Capacity==TrueCaps(i));
end
CountCaps
sum(CountCaps)-CountCaps(1,6)

% Reset mpc1
OriginalMPC=mpc1;
NumBranches=length(mpc1.branch(:,6));
% Generate a initial failure table

for i=1:NumIt
    %     2 or 3 failures
    %     b = 1 + ceil(2*rand);
    % set to Initial Failures
    b=InitialFailures;
    randomindex = randperm(NumBranches);
    temp = randomindex(1:b);
    IniFidx = randomindex(1:b);
    %IniFidx = [54 108 9];
    IniFtable{1,i} = IniFidx;
    %Capacity(IniFidx)
end

%Capacity
DGRatioVector = [LoadGenerationRatio]; %(r in paper)
DeltaVector = [EstimationError]; % alpha, error (e in paper)
NoCoopPercentageVector = [LoadShedConstant]; % Beta, (\theta in paper)

tic
for idx=1:length(NoCoopPercentageVector)
    NoCoopPercentage=NoCoopPercentageVector(idx);
    for DGRatio=DGRatioVector
        clear mpc1;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        mpc1 = OriginalMPC;
        BranchMatrix=mpc1.branch;
        NumBranches=length(BranchMatrix(:,1));
        BusMatrix=mpc1.bus;
        NumBuses=length(BusMatrix(:,1));
        GenMatrix=mpc1.gen;
        NumGens=length(GenMatrix(:,1));
        
        Degrees = DegreeofLines(NumBranches,mpc1); % Find the degree of line
        HopDist = HopDistance(NumBranches,NumBuses,mpc1);% Finds the hop distance between all links
        
        %%%%% Calculating the total demand and generation capacity of the grid%%%%%
        %         =Demand/Generation;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        for alpha=DeltaVector
            clear States capalogcell;
            StateCounter=0; %counts the number of possible states
            % failures capacity log
            capalogcell = {};
            
            StatesCell = cellmat(NumIt, 1, 1000, 14);
            
            parfor s=1:NumIt % for every iteration under the same setting
                %s %print out s
                StatesCell(s, 1) = {DCPowerFlowSimulation(OriginalMPC, NumBranches, NoCoopPercentage, StateCounter, TrueCaps, DGRatio, WhichInitialLoad, Capacity, s, IniFtable, Demand, Degrees, HopDist, DemandIndex, alpha)};

            end
            %Temporary -- turn states cell array back to array
            States = cell2mat(StatesCell); %Turn cells to states matrix
%             for s=1:NumIt
%                 
%                 StatesMat = cell2mat(StatesCell(s,1));
%                 n = 1;
%                 while StatesMat(n, 8) ~= -1
%                     StateCounter = StateCounter+1;
%                     States(StateCounter) = StatesMat(n);
%                     n = n+1;
%                 end
%                 StateCounter = StateCounter+1;
%                 States(StateCounter) = StatesMat(n);
%             end
            
            save(strcat('CapData02102018IniF', num2str(b),...
                'r', num2str(DGRatio),'e',num2str(alpha),...
                'Theta',num2str(NoCoopPercentage), '.mat'), 'States', 'capalogcell');
        end
    end
end




capalogcell;
toc




% for line failure plot with different capacities: PD , 01/11/2018
capFailSeq = capalogcell;
% Initialization
s = 1;
stopIdx  = 1;
d = length(capalogcell);
timeSteps = d - s + 1;
failedLineatTimeSteps = zeros(numel(TrueCaps),timeSteps); % failure counters
for timeIdx = 1:1:timeSteps
    lineFailed = capFailSeq{1,timeIdx}; %Find failed lines at time index
    for j  = 1:length(lineFailed)
        c = lineFailed(j,1);
        if c == 20
            failedLineatTimeSteps (1,timeIdx) = failedLineatTimeSteps (1,timeIdx) + 1;
        elseif c == 80
            failedLineatTimeSteps (2,timeIdx) = failedLineatTimeSteps (2,timeIdx) + 1;
        elseif c == 200
            failedLineatTimeSteps (3,timeIdx) = failedLineatTimeSteps (3,timeIdx) + 1;
        elseif c == 500
            failedLineatTimeSteps (4,timeIdx) = failedLineatTimeSteps (4,timeIdx) + 1;
        elseif c == 800
            failedLineatTimeSteps (5,timeIdx) = failedLineatTimeSteps (5,timeIdx) + 1;
        elseif c == 9900
            failedLineatTimeSteps (6,timeIdx) = failedLineatTimeSteps (5,timeIdx) + 1;
        end
        
    end
end
%failedLineatTimeSteps
totalFail = cumsum(failedLineatTimeSteps,2);
totalFail(1:5,:);
plot(totalFail(1:5,:)')
xlim([0 10])

Blackoutsize=zeros(NumBranches,1);
for i=1:length(States(:,1))
    if(States(i,8)==-1)
        Blackoutsize(States(i,1))=Blackoutsize(States(i,1))+1;
    end
end
bar(Blackoutsize);
loglog(1:231,Blackoutsize);

% For 118 case
% NumberOfLines = 186;
% 
% total_states = zeros(1, NumberOfLines);
% stable_states = zeros(1, NumberOfLines);
% 
% for i = 1:length(States)
%     if States(i,1) > 0
%         total_states(States(i,1)) = total_states(States(i,1)) + 1;
%     end
%     if States(i,8) == -1
%         if States(i,1) > 0
%             stable_states(States(i,1)) = stable_states(States(i,1)) + 1;
%         end
%     end
% end
% 
% cascade_stop = zeros(1, NumberOfLines);
% for i = 1:NumberOfLines
%     if total_states(i) ~= 0
%         cascade_stop(i) = stable_states(i)/total_states(i);
%     end
% end
% 
% figure (2)
% plot(5:NumberOfLines, cascade_stop(5:NumberOfLines))
% xlabel('Number of failed transmission lines')
% ylabel('Cascade-stop probability')

end

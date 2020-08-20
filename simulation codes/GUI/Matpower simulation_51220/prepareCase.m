function [originalNumBus, originalNumGen, originalNumBran, NumBuses, mpc1, LoadGenMatch, Generation, Demand, DemandIndex, FakeCapRate, FlowCap, TrueCaps, NumBranches, WhichInitialLoad, OriginalMPC] = prepareCase(CaseName)



FakeCapRate = 1; % fake capacity
%% Parameter initialization
TrueCaps=[50 100 200 400 800]; % quantized capacity
%% Initial load on which the capacity of lines will be determined
mpc1 = loadcase(CaseName);
mpc1 = S_ReadyTheCase(mpc1);
%% keep the original values of number of buses and gens and branches before changing
originalNumBus=length(mpc1.bus(:,1));
originalNumGen=length(mpc1.gen(:,1));
originalNumBran=length(mpc1.branch(:,1));
NumBuses = length(mpc1.bus(:,1));
NumBranches = originalNumBran;
%% Seperate the buses with both load and generators into seperate load and generator buses
[mpc1 LoadGenMatch] = S_SeperateGenAndLoad(mpc1);

[WhichInitialLoad, Generation, Demand, DemandIndex] = S_FindFullLoadOfGrid(mpc1);

%% Calculating the total demand and generation capacity of the grid%%%%%
%if strcmp(CaseName, 'case2383wp')
%   [WhichInitialLoad, Generation, Demand, DemandIndex] = S_FindFullLoadOfGrid_LargeGrid(mpc1);
%else
%   [WhichInitialLoad, Generation, Demand, DemandIndex] = S_FindFullLoadOfGrid(mpc1);
%end
%%
clear mpc1; % clear because
mpc1 = loadcase(CaseName);
mpc1 = S_ReadyTheCase(mpc1);
%% check if any negative load
for i=1:NumBuses
    if (mpc1.bus(i,3)<0) % if the real power of the bus is negative
        mpc1.bus(i,3) = abs(mpc1.bus(i,3));
    end
end
%% Seperate the buses with both load and generators into seperate load and generator buses
[mpc1 LoadGenMatch] = S_SeperateGenAndLoad(mpc1);
%% Find installed capacity of a transmission line and use it as rateA threshold
[Capacity, FlowCap] = S_CapFinder(WhichInitialLoad,mpc1,TrueCaps,originalNumBran);
mpc1.branch(:,6) = FakeCapRate*Capacity;
CountCaps=zeros(1,length(TrueCaps));
for i=1:length(TrueCaps)
    CountCaps(i)=sum(Capacity==TrueCaps(i));
end
%% Reset mpc1, PD: take mpc with separated load and generator
OriginalMPC = mpc1; % this is the MPC with separated load and generator
end
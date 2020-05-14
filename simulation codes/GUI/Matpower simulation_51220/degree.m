
clc;
clear all;
close all;
define_constants;
CaseName='case118';

mpc1 = loadcase(CaseName);
mpc1 = S_ReadyTheCase(mpc1);

BranchMatrix=mpc1.branch;
BusMatrix=mpc1.bus;
GenMatrix=mpc1.gen;

NumBranches=length(BranchMatrix(:,1));
NumBuses=length(BusMatrix(:,1));
NumGens=length(GenMatrix(:,1));
AdjMatrix=zeros(NumBuses,NumBuses);
for j=1:NumBranches
    AdjMatrix(mpc1.branch(j,1),mpc1.branch(j,2))=1;
    AdjMatrix(mpc1.branch(j,2),mpc1.branch(j,1))=1;
end

G = graph(AdjMatrix);
D = degree(G);
mean(D)

path = distances(G);
average_path_length = sum(path);
tot = sum(average_path_length);
tot/(118*117)


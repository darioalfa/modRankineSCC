function [s, enth, sfwh, ent_fwh, sdeair, ent_deair] = cycle_HS_diagram(cobj, mode)
%cycle_TS_diagram Generate TS diagram of cycle
%   mode 'simple' -> Only external area of TS
%   mode 'complex' -> Full diagram
%   mode 'turbine' -> Simple turbine diagram

%%%%%%%%%%%%
% Pressures vector. Start at condenser input
pressures=zeros(200,1);
idx=1;

if (strcmp(mode,'simple') || strcmp(mode,'complex'))
    pressures(1:3,1) = [cobj.tur{2}.EX(1,end);...
        cobj.co_pmp.P_in;...
        cobj.co_pmp.P_out];
    
    idx=4;
    for i=cobj.N_FWH:-1:cobj.N_FWH_HP+1
        pressures(idx)=cobj.fwh{i}.P_C;
        pressures(idx+1)=cobj.fwh{i}.P_C;
        
        idx=idx+2;
    end
    
    pressures(idx)=cobj.fw_pmp.P_in;
    idx=idx+1;
    pressures(idx)=cobj.fw_pmp.P_out;
    idx=idx+1;
    
    for i=cobj.N_FWH_HP:-1:1
        pressures(idx)=cobj.fwh{i}.P_C;
        pressures(idx+1)=cobj.fwh{i}.P_C;
        
        idx=idx+2;
    end
    
    % Heater - apply heater charge loss. P_HTR is output pressure
    loss=linspace(1-cobj.HTR_ploss,1,30);
    for i=1:30
        pressures(idx)=cobj.P_HTR/loss(i);
        idx=idx+1;
    end
end

% HP Turbine
for i=1:size(cobj.tur{1}.adm_EX,2)-1
    pressures(idx)=cobj.tur{1}.adm_EX(i);
    idx=idx+1;
end

for i=1:size(cobj.tur{1}.EX,2)
    pressures(idx)=cobj.tur{1}.EX(i);
    idx=idx+1;
end

% Reheater- apply heater charge loss. P_RHTR is output pressure
P_RHTR=cobj.tur{2}.P_in;
loss=linspace(1-cobj.RHTR_ploss,1,30);
for i=1:30
    pressures(idx)=P_RHTR/loss(i);
    idx=idx+1;
end

% IP LP Turbine
pressures(idx)=cobj.tur{2}.adm_EX(1);
idx=idx+1;

for i=1:size(cobj.tur{2}.EX,2)
    pressures(idx)=cobj.tur{2}.EX(1,i);
    idx=idx+1;
end

% Remove zeros
pressures=pressures(pressures > 0);

%%%%%%%%%%%%
% Enthalpies vector. Start at condenser input
enth=zeros(200,1);
idx=1;

if (strcmp(mode,'simple') || strcmp(mode,'complex'))
    enth(1:3,1) = [cobj.tur{2}.h_st(end);...
        cobj.co_pmp.h_in;...
        cobj.co_pmp.h_out];
    
    idx=4;
    for i=cobj.N_FWH:-1:cobj.N_FWH_HP+1
        enth(idx)=cobj.fwh{i}.h_Cin;
        enth(idx+1)=cobj.fwh{i}.h_Cout;
        
        idx=idx+2;
    end
    
    enth(idx)=cobj.fw_pmp.h_in;
    idx=idx+1;
    enth(idx)=cobj.fw_pmp.h_out;
    idx=idx+1;
    
    for i=cobj.N_FWH_HP:-1:1
        enth(idx)=cobj.fwh{i}.h_Cin;
        enth(idx+1)=cobj.fwh{i}.h_Cout;
        
        idx=idx+2;
    end
    
    % Heater
    s_in=XSteam('s_ph',cobj.fwh{1}.P_C,cobj.fwh{1}.T_Cout-273);
    s_out=cobj.tur{1}.s_in;
    s=linspace(s_in,s_out,30);
    
    for i=1:30
        enth(idx)=XSteam('h_ps',pressures(idx),s(i));
        idx=idx+1;
    end
end

% HP Turbine
for i=1:size(cobj.tur{1}.adm_h,2)-1
    enth(idx)=cobj.tur{1}.adm_h(i);
    idx=idx+1;
end

for i=1:size(cobj.tur{1}.EX,2)
    enth(idx)=cobj.tur{1}.h_st(i);
    idx=idx+1;
end

% Reheater
s_in=cobj.tur{1}.s_st(end);
s_out=cobj.tur{2}.s_in;
s=linspace(s_in,s_out,30);
    
for i=1:30
    enth(idx)=XSteam('h_ps',pressures(idx),s(i));
    idx=idx+1;
end

% IP LP Turbine
enth(idx)=cobj.tur{2}.adm_h(1);
idx=idx+1;

for i=1:size(cobj.tur{2}.EX,2)
    enth(idx)=cobj.tur{2}.h_st(i);
    idx=idx+1;
end

% Remove zeros
enth=enth(enth > 0);

%%%%%%%%%%%%
% Calculate enthropy
% fun=@(p,h) s_ph_97(p,h);
fun=@(p,h) XSteam('s_ph',p,h);

s = arrayfun(fun,pressures,enth);

%%%%%%%%%%%%
% Return FWH lines as well if mode is "complex"
if strcmp(mode,'complex')
    
    % Compute number of bypassed FWH
    num_bypassed=0;
    for h=1:cobj.N_FWH
        if cobj.fwh{h}.bypass==1
            num_bypassed=num_bypassed+1;
        end
    end
    
    pres_fwh=zeros(cobj.N_FWH-num_bypassed,42);
    ent_fwh=zeros(cobj.N_FWH-num_bypassed,42);
    idx_vap=15;
    
    for h=1:cobj.N_FWH
        
        if cobj.fwh{h}.bypass==0
            ent_start=cobj.fwh{h}.h_ex;
            ent_vapL=XSteam('hL_p',cobj.fwh{h}.P_ex);
            if cobj.fwh{h}.x_ex==-1
                ent_vapS=XSteam('hV_p',cobj.fwh{h}.P_ex);
            else
                ent_vapS=ent_start;
            end
            ent_end=cobj.fwh{h}.h_Hout;
            
            idx=1;
            
            % Compensate for pressure loss from turbine to FWH inlet
            pres_fwh(h,idx)=cobj.fwh{h}.P_ex/(1-cobj.EX_ploss(h));
            ent_fwh(h,idx)=ent_start;
            
            idx=idx+1;
            
            for i=1:30
                pres_fwh(h,idx)=cobj.fwh{h}.P_ex;
                
                % Set condensation at middle of process
                if i<idx_vap
                    ent_fwh(h,idx)=ent_start+(ent_vapS-ent_start)*((i-1)/(idx_vap-1));
                elseif i==idx_vap
                    pres_fwh(h,idx+1)=cobj.fwh{h}.P_ex;
                    
                    ent_fwh(h,idx)=ent_vapS;
                    ent_fwh(h,idx+1)=ent_vapL;
                                        
                    idx=idx+1;
                else
                    ent_fwh(h,idx)=ent_vapL+(ent_end-ent_vapL)*((i-idx_vap-1)/idx_vap);
                end
                                
                idx=idx+1;
            end
            
            if cobj.fwh{h}.md~=0
                pres_fwh(h,idx:end)=pres_fwh(h,idx-1);
                ent_fwh(h,idx:end)=ent_fwh(h,idx-1);
                
                pres_fwh(h-1,idx:end)=linspace(cobj.fwh{h-1}.P_ex,cobj.fwh{h}.P_ex,10);
                ent_fwh(h-1,idx:end)=ones(1,10)*cobj.fwh{h-1}.h_Hout;
            end
        end
        
    end
    
    % Drainbacks to deair and condenser
    fwh_to_deair=cobj.N_FWH_HP;
    
    idx=33;
    
    pres_fwh(fwh_to_deair,idx:end)=linspace(cobj.fwh{fwh_to_deair}.P_ex,...
        cobj.co_pmp.P_out,10);
    ent_fwh(fwh_to_deair,idx:end)=ones(1,10)*cobj.fwh{fwh_to_deair}.h_Hout;
        
    fwh_to_con=cobj.N_FWH;
    
    idx=33;
    
    pres_fwh(fwh_to_con,idx:end)=linspace(cobj.fwh{fwh_to_con}.P_ex,...
        cobj.co_pmp.P_in,10);
    ent_fwh(fwh_to_con,idx:end)=ones(1,10)*cobj.fwh{fwh_to_con}.h_Hout;
            
    % Calculate entropy
    sfwh = arrayfun(fun,pres_fwh,ent_fwh);
    
    % Deareator
    pres_deair=zeros(1,32);
    ent_deair=zeros(1,32);
    idx_vap=15;
    
    ent_start=cobj.h_DAex;
    ent_vapL=XSteam('hL_p',cobj.co_pmp.P_out);
    ent_vapS=XSteam('hV_p',cobj.co_pmp.P_out);
    ent_end=cobj.h_DA_out;
    
    idx=1;
    
    % Compensate for pressure loss from turbine to FWH inlet
    pres_deair(idx)=cobj.co_pmp.P_out/(1-cobj.DAEX_ploss);
    ent_deair(idx)=ent_start;
    
    idx=idx+1;
    
    for i=1:30
        pres_deair(idx)=cobj.co_pmp.P_out;
        
        % Set condensation at middle of process
        if i<idx_vap
            ent_deair(idx)=ent_start+(ent_vapS-ent_start)*((i-1)/(idx_vap-1));
        elseif i==idx_vap
            pres_deair(idx+1)=cobj.co_pmp.P_out;
            
            ent_deair(idx)=ent_vapS;
            ent_deair(idx+1)=ent_vapL;
                        
            idx=idx+1;
        else
            ent_deair(idx)=ent_vapL+(ent_end-ent_vapL)*((i-idx_vap-1)/idx_vap);
        end
                
        idx=idx+1;
    end
    
    sdeair = arrayfun(fun,pres_deair,ent_deair);
    
else
    sfwh=0;
    ent_fwh=0;
    sdeair=0;
    ent_deair=0;
end

end


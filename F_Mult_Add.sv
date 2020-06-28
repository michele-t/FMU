module lampFPU_FMA( clk,rst,
//inputs
sign_op1_i,mant_op1_i,exp_op1_i,isZ_op1_i,isInf_op1_i, isSNAN_op1_i, isQNAN_op1_i,
sign_op2_i,mant_op2_i,exp_op2_i,isZ_op2_i,isInf_op2_i, isSNAN_op2_i, isQNAN_op2_i,
sign_op3_i,mant_op3_i,exp_op3_i,isInf_op3_i, isSNAN_op3_i, isQNAN_op3_i,
doFMU_i,is_mult_sub_i,is_add_sub_i, // Used to implement fused ADD/SUB
//output
res_sign_o,res_mant_o, res_exp_o,
is_Overflow_o,is_Underflow_o,is_to_round_o,valid_o


);
import FPU_pkg::*;

input clk,rst;

input [F_SIGN-1:0]          sign_op1_i;
input [(F_MANT-1)+1:0]      mant_op1_i; // +1 due to hidden bit
input [(F_EXP-1)+1:0]       exp_op1_i;
input                       isZ_op1_i;
input						isInf_op1_i;
input						isSNAN_op1_i;
input						isQNAN_op1_i;



input [F_SIGN-1:0]          sign_op2_i;
input [(F_MANT-1)+1:0]      mant_op2_i; // +1 due to hidden bit
input [(F_EXP-1)+1:0]       exp_op2_i;
input                       isZ_op2_i;
input						isInf_op2_i;
input						isSNAN_op2_i;
input						isQNAN_op2_i;


input [F_SIGN-1:0]          sign_op3_i;
input [(F_MANT-1)+1:0]      mant_op3_i; // +1 due to hidden bit
input [(F_EXP+1)-1:0]       exp_op3_i;
input						isInf_op3_i;
input						isSNAN_op3_i;
input						isQNAN_op3_i;


input                       doFMU_i;
input                       is_mult_sub_i;
input                       is_add_sub_i;

output logic [F_SIGN-1:0]          res_sign_o;
output logic [5+(F_MANT-1):0]      res_mant_o; // +1 due to hidden bit +guard +round +sticky
output logic [F_EXP-1:0]           res_exp_o;
output logic                       is_Overflow_o;
output logic                       is_Underflow_o;
output logic                       is_to_round_o;
output logic                       valid_o;

logic [2*(F_MANT+1)-1:0]        ext_mult_mant_temp;// +2 hidden bit due to extended result
logic [F_SIGN-1:0]              mult_sign; // multiplication sign
logic [F_EXP-1+1:0]             biased_mult_exp_denorm,biased_out_exp_denorm; //+1 for overflow check
logic [F_EXP-1+1:0]             op3_mant_allign;
logic [3*(F_MANT+1)-1:0]        op3_mant_shift_temp; // we shift both left or right so we need extra bit 3*F_MANT
                                                    // to store mantissa, +3bits for hidden bit 
logic                         op3GreaterProd;                                                    
logic [3*(F_MANT+1)-1:0]      mant_small_temp; // one extra bit for 2' comp
logic [3*(F_MANT+1)-1:0]      mant_high_temp;
logic [3*(F_MANT+1)-1+1:0]    mant_small_temp_comp2;

                                                     
logic [3*(F_MANT+1)-1+1:0]        out_mant_denorm,out_mant_denorm_r; // mantissa of AxB+C denormalized 
logic [3*(F_MANT+1)-1:0]          out_mant_norm;
logic [F_EXP-1+1:0]               res_exp_o_denorm,res_exp_o_denorm_r;
logic [F_EXP-1+1:0]               res_exp_o_norm;
logic                             sign_postnorm;

logic                           doOpSub;
logic                           mult_GT_op3;
logic                           sign_initial_temp;


logic [F_EXP-1+1:0]             norm_left_shift;
logic [F_EXP-1+1:0]             norm_right_shift;

logic                           sticky_allign,sticky_allign_r;
logic                           sticky_denorm;
logic                           sticky_norm;
logic [F_SIGN-1:0]              res_sign;
logic [(F_MANT-1)+5:0]          res_mant;
logic [F_EXP-1:0]               res_exp; 
logic                           is_Overflow_postnorm,is_Overflow_postmult,is_Overflow;
logic                           is_Underflow_postnorm,is_Underflow;
logic                           is_to_round;

logic                           doFMU_r;
logic							is_mult_sub_r;
logic							is_add_sub_r;
logic                           isZ_op1_r;
logic							isInf_op1_r;
logic							isSNAN_op1_r;
logic							isQNAN_op1_r;
logic                           isZ_op2_r;
logic							isInf_op2_r;
logic							isSNAN_op2_r;
logic							isQNAN_op2_r;
logic							isInf_op3_r;
logic							isSNAN_op3_r;
logic							isQNAN_op3_r;

logic                           mult_sign_r;
logic                           op3_sign_r;

logic							isCheckNanInfValid;
logic							isZeroRes;
logic							isCheckInfRes;
logic							isCheckNanRes;
logic							isCheckSignRes;
logic                           valid;




// Sequential logic part (rst and update every clk)
always @(posedge clk) begin
    if(rst) begin
        out_mant_denorm_r       <=  '0;
        sticky_allign_r         <=  '0;
        res_exp_o_denorm_r      <=  '0;
        
        doFMU_r                 <=  '0;
        is_mult_sub_r			<=	'0;
        is_add_sub_r			<=	'0;
        isZ_op1_r               <=  '0;
		isInf_op1_r				<=	'0;
		isSNAN_op1_r			<=	'0;
		isQNAN_op1_r			<=	'0;
		isZ_op2_r               <=  '0;
		isInf_op2_r				<=	'0;
		isSNAN_op2_r			<=	'0;
		isQNAN_op2_r			<=	'0;
	    isInf_op3_r				<=	'0;
		isSNAN_op3_r			<=	'0;
		isQNAN_op3_r			<=	'0;

        mult_sign_r             <=  '0;
        op3_sign_r              <=  '0;
        
        res_sign_o              <=  '0;
        res_mant_o              <=  '0;
        res_exp_o               <=  '0;
        is_Overflow_o           <=  '0;
		is_Underflow_o          <=  '0;
		is_to_round_o           <=  '0;

       
    
    end 
    else begin
        out_mant_denorm_r       <=  out_mant_denorm;
        sticky_allign_r         <=  sticky_allign;
        res_exp_o_denorm_r      <=  res_exp_o_denorm;
        
        doFMU_r                 <=  doFMU_i;
        is_mult_sub_r			<=	is_mult_sub_i;
        is_add_sub_r            <=  is_add_sub_i;
        isZ_op1_r               <=  isZ_op1_i;
		isInf_op1_r				<=	isInf_op1_i;
		isSNAN_op1_r			<=	isSNAN_op1_i;
		isQNAN_op1_r			<=	isQNAN_op1_i;
        isZ_op2_r               <=  isZ_op2_i;
		isInf_op2_r				<=	isInf_op2_i;
		isSNAN_op2_r			<=	isSNAN_op2_i;
		isQNAN_op2_r			<=	isQNAN_op2_i;
		isInf_op3_r				<=	isInf_op3_i;
		isSNAN_op3_r			<=	isSNAN_op3_i;
		isQNAN_op3_r			<=	isQNAN_op3_i;
		
        mult_sign_r             <=  mult_sign;
        op3_sign_r              <=  sign_op3_i;
        
        
        res_mant_o              <=  res_mant;
        res_exp_o               <=  res_exp;
        res_sign_o              <=  res_sign;
        is_Overflow_o           <=  is_Overflow;
        is_Underflow_o          <=  is_Underflow;
        is_to_round_o           <=  is_to_round;
        valid_o                 <=  valid;

    end
end






always @ (*) begin
    mult_sign=sign_op1_i^sign_op2_i;
    
    ext_mult_mant_temp=mant_op1_i*mant_op2_i;
    
    biased_mult_exp_denorm=exp_op1_i+exp_op2_i-F_EXP_BIAS;
    
    op3_mant_shift_temp={9'b0,mant_op3_i,7'b0};
    
    op3GreaterProd=0;
    if(biased_mult_exp_denorm>exp_op3_i)begin
    
        op3_mant_allign=biased_mult_exp_denorm-exp_op3_i;
        
        op3_mant_shift_temp=op3_mant_shift_temp>>op3_mant_allign; //AxB>C so right shift
        sticky_allign=FUNC_allign_StickyBit(op3_mant_allign,op3_mant_shift_temp);
        
        mult_GT_op3=1;
        
    end
    else if(biased_mult_exp_denorm<exp_op3_i) begin 
    
        op3_mant_allign=exp_op3_i-biased_mult_exp_denorm;
        
        if(op3_mant_allign>F_MANT+2)
        
            op3GreaterProd=1;
        else begin   
                 
            op3_mant_shift_temp=op3_mant_shift_temp<<op3_mant_allign; //AxB<C so left shift
            mult_GT_op3=0;
            
            
        end
        
    end
    
    else begin
        if(ext_mult_mant_temp[2*F_MANT-1+1:F_MANT]>mant_op3_i)
            mult_GT_op3=1;
            
        else
            mult_GT_op3=0;
    end
    if (op3GreaterProd) begin
    
        res_exp_o_denorm=exp_op3_i;
        out_mant_denorm=op3_mant_shift_temp;
        mult_GT_op3=0;
    end
    else begin
        res_exp_o_denorm=biased_mult_exp_denorm;
    
        mant_small_temp= mult_GT_op3 ? {op3_mant_shift_temp}:{8'b0,ext_mult_mant_temp};
        
        mant_high_temp= mult_GT_op3 ? {8'b0,ext_mult_mant_temp}:{op3_mant_shift_temp};
        
        doOpSub=(!(is_mult_sub_i^is_add_sub_i)&&(mult_sign!=sign_op3_i))||((is_mult_sub_i^is_add_sub_i)&&(mult_sign==sign_op3_i));
    
        mant_small_temp_comp2=doOpSub? ({1'b0,mant_small_temp}^{(3*(F_MANT+1)){1'b1}})+1'b1:{1'b0,mant_small_temp};
       
    
        out_mant_denorm=mant_small_temp_comp2+{1'b0/*2 comp*/,mant_high_temp};
        /* We need to check leading zeroes before the radix point due to left shift and after due to right shift
        1st we evaluate if we need to left shift, than if is not we check for right shift
    
        */
    end
    sign_postnorm=mult_GT_op3 ? (!is_mult_sub_i ? mult_sign : !mult_sign ):(!is_add_sub_i ? sign_op3_i : !sign_op3_i);
    
    //REGISTERED
    

    is_Overflow_postnorm		= '0;
    is_Underflow_postnorm	= '0;
    
    
    if(res_exp_o_denorm_r[F_EXP+1-1]) begin
    
        is_Overflow_postmult=1;
        res_exp_o_norm='1;
        out_mant_norm='0;
        
    end
    else begin 
    
        is_Overflow_postmult=0;
        norm_right_shift= FUNC_left_LeadingZeroes(out_mant_denorm_r[3*(F_MANT+1)-1:2*F_MANT]);
        sticky_norm=FUNC_calcStickyBit(out_mant_denorm_r[F_MANT-1-2:0])|sticky_allign_r;
        
        if (norm_right_shift==0 && !out_mant_denorm_r[2*F_MANT]) begin
        
            norm_left_shift=FUNC_right_LeadingZeroes(out_mant_denorm_r[2*F_MANT-1:0]);
            res_exp_o_norm=res_exp_o_denorm_r-norm_left_shift;
            
            if(norm_left_shift>res_exp_o_denorm_r) begin
            
                is_Underflow_postnorm=1;
                res_exp_o_norm='0;
            end
               
            
            out_mant_norm=out_mant_denorm_r<<norm_left_shift;               
            sticky_norm=FUNC_calcStickyBit(out_mant_norm[F_MANT-1-2:0])|sticky_allign_r;
            
            
       end
    
 
        else if (norm_right_shift==0 && out_mant_denorm_r[2*F_MANT]) begin
        
            res_exp_o_norm=res_exp_o_denorm_r;
            out_mant_norm=out_mant_denorm_r;
         
        end
        else begin
        
            res_exp_o_norm=res_exp_o_denorm_r+norm_right_shift;
            if (res_exp_o_denorm_r[F_EXP-1+1]) begin
            
                is_Overflow_postnorm=1;
                res_exp_o_norm='1;
                out_mant_norm='0;
            end
            else begin
            
                out_mant_norm=out_mant_denorm_r>>norm_right_shift;
            
                sticky_norm=FUNC_calcStickyBit(out_mant_norm[F_MANT-1-2:0])|sticky_allign_r;
            end
        
        end
    end
    
    {isCheckNanInfValid, isCheckInfRes, isCheckNanRes, isCheckSignRes} = FUNC_calcInfNanRes(
					is_mult_sub_r,is_add_sub_r,												/*operator*/
					isZ_op1_r, isInf_op1_r,  isSNAN_op1_r, isQNAN_op1_r,		
					isZ_op2_r, isInf_op2_r,  isSNAN_op2_r, isQNAN_op2_r,
					mult_sign_r, op3_sign_r,
					isInf_op3_r,  isSNAN_op3_r, isQNAN_op3_r									
			);

		unique if (isCheckInfRes)
		
			{res_sign, res_exp, res_mant}	=	{isCheckSignRes, INF_E_F, 5'b0};
		else if (isCheckNanRes)
		
			{res_sign, res_exp, res_mant}	=	{isCheckSignRes, QNAN_E_F, 5'b0};
		else begin
		
		  out_mant_norm[F_MANT-1-2]=sticky_norm|out_mant_norm[F_MANT-1-2];
		  {res_sign, res_exp, res_mant}	=	{sign_postnorm, res_exp_o_norm[F_EXP-1:0],out_mant_norm[2*(F_MANT+1)-1:F_MANT-1-2]};
		  is_Overflow	= is_Overflow_postnorm||is_Overflow_postmult;
		  is_Underflow	= is_Underflow_postnorm;
		  is_to_round	= ~isCheckNanInfValid;
          valid         = doFMU_r;

	      end    

  end





endmodule
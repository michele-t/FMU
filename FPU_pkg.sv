package FPU_pkg;
    parameter F_LENGHT=16;
    parameter F_SIGN=1;
    parameter F_MANT=7;
    parameter F_EXP= 8;
    parameter F_EXP_BIAS=(2 ** (F_EXP-1))-1;
    parameter EXP_MAX= (2**F_EXP)-1;
    parameter INF_E_F			=	15'b111111110000000; // w/o sign
	parameter SNAN_E_F			=	15'b111111110111111; // w/o sign
	parameter QNAN_E_F			=	15'b111111111000000; // w/o sign
	parameter ZERO_E_F			=	15'b000000000000000; // w/o sign
    


    function automatic logic[$clog2(F_MANT+3)-1:0 ] FUNC_left_LeadingZeroes(input [F_MANT+3-1:0] up_denorm_mant);
        casez(up_denorm_mant)
            10'b0000000000: return 'd0;
            10'b0000000001: return 'd0;   
            10'b000000001?: return 'd1;
            10'b00000001??: return 'd2;
            10'b0000001???: return 'd3;
            10'b000001????: return 'd4;
            10'b00001?????: return 'd5;   
            10'b0001??????: return 'd6;   
            10'b001???????: return 'd7;   
            10'b01????????: return 'd8;   
            10'b1?????????: return 'd9;   

        endcase
    endfunction
    
     function automatic logic[$clog2(2*F_MANT)-1:0 ] FUNC_right_LeadingZeroes(input [2*F_MANT-1:0] low_denorm_mant);
        casez(low_denorm_mant)
            14'b1?????????????: return 'd1;
            14'b01????????????: return 'd2;
            14'b001???????????: return 'd3;
            14'b0001??????????: return 'd4;
            14'b00001?????????: return 'd5;
            14'b000001????????: return 'd6;
            14'b0000001???????: return 'd7;
            14'b00000001??????: return 'd8;
            14'b000000001?????: return 'd9;
            14'b0000000001????: return 'd10;
            14'b00000000001???: return 'd11;
            14'b000000000001??: return 'd12;
            14'b0000000000001?: return 'd13;
            14'b00000000000001: return 'd14;
           
            
        
        endcase 
     endfunction
     
     function automatic logic FUNC_allign_StickyBit(input [F_EXP-1:0] right_shift,
     input [3*(F_MANT+1)-1:0] mant);
        case(right_shift)
            8'd0: return 1'b0;
            8'd1: return 1'b0;
            8'd2: return 1'b0;
            8'd3: return 1'b0;
            8'd4: return 1'b0;
            8'd5: return 1'b0;
            8'd6: return 1'b0;
            8'd7: return 1'b0;
            8'd8: return mant[7];
            8'd9: return |mant[7+:1];
            8'd10: return |mant[7+:2];
            8'd11: return |mant[7+:3];
            8'd12: return |mant[7+:4];
            8'd13: return |mant[7+:5];
            8'd14: return |mant[7+:6];
            8'd15: return |mant[7+:7];
            
            default: return |mant[7+:7];
          

        endcase
     
     
     endfunction
     
     function automatic logic FUNC_calcStickyBit(input [F_MANT-1-2:0] lower_bits); // -2 for guard and round bit
        return |lower_bits;
     
     endfunction
     
	
	function automatic logic[3:0] FUNC_calcInfNanRes (
				input isMultSub_i, input isOpSub_i,
				input isZero_op1_i, isInf_op1_i,  input isSNan_op1_i, input isQNan_op1_i,
				input isZero_op2_i, isInf_op2_i,  input isSNan_op2_i, input isQNan_op2_i,
				input sign_mult_i,input sign_op3_i,
				input isInf_op3_i, input isSNan_op3_i, input isQNan_op3_i


			);

		logic realMult_sign,realOp3_sign;
		logic isNan_op1 = isSNan_op1_i || isQNan_op1_i;
		logic isNan_op2 = isSNan_op2_i || isQNan_op2_i;
		logic isNan_op3 = isSNan_op3_i || isQNan_op3_i;

		logic isValidRes, isInfRes, isNanRes, signRes;
		realMult_sign   = sign_mult_i ^ isMultSub_i;
		realOp3_sign 	= sign_op3_i ^ isOpSub_i;

		isValidRes 		= (isZero_op1_i|| isZero_op2_i ||isInf_op1_i || isInf_op2_i ||isInf_op3_i|| isNan_op1 || isNan_op2||isNan_op3) ? 1 : 0;
		if (isNan_op1)
		begin //sign is not important, since a Nan remains a nan what-so-ever
			isInfRes = 0; isNanRes = 1; signRes = sign_mult_i;
		end
		else if (isNan_op2)
		begin
			isInfRes = 0; isNanRes = 1; signRes = sign_mult_i;
		end
		else if (isNan_op3)
		begin
			isInfRes = 0; isNanRes = 1; signRes = sign_op3_i;
		end
		else // both are not NaN
		begin
			case({isZero_op1_i,isZero_op2_i,isInf_op1_i,isInf_op2_i,realMult_sign,realOp3_sign,isInf_op3_i})
			     7'b00_00_00_0:begin isNanRes = 0; isInfRes = 0; signRes = 0;   end
			     7'b00_00_00_1:begin isNanRes = 0; isInfRes = 1; signRes = 0;   end
			     7'b00_00_01_0:begin isNanRes = 0; isInfRes = 0; signRes = 0;   end
			     7'b00_00_01_1:begin isNanRes = 0; isInfRes = 1; signRes = 1;   end
			     7'b00_00_10_0:begin isNanRes = 0; isInfRes = 0; signRes = 0;   end
			     7'b00_00_10_1:begin isNanRes = 0; isInfRes = 1; signRes = 1;   end
			     7'b00_00_11_0:begin isNanRes = 0; isInfRes = 0; signRes = 0;   end
			     7'b00_00_11_1:begin isNanRes = 0; isInfRes = 1; signRes = 0;   end
			     7'b00_01_00_0:begin isNanRes = 0; isInfRes = 1; signRes = 0;   end
			     7'b00_01_00_1:begin isNanRes = 0; isInfRes = 1; signRes = 0;   end
			     7'b00_01_01_0:begin isNanRes = 0; isInfRes = 1; signRes = 0;   end
			     7'b00_01_01_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b00_01_10_0:begin isNanRes = 0; isInfRes = 1; signRes = 1;   end
			     7'b00_01_10_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b00_01_11_0:begin isNanRes = 0; isInfRes = 1; signRes = 1;   end
			     7'b00_01_11_1:begin isNanRes = 0; isInfRes = 1; signRes = 1;   end
			     7'b00_10_00_0:begin isNanRes = 0; isInfRes = 1; signRes = 0;   end
			     7'b00_10_00_1:begin isNanRes = 0; isInfRes = 1; signRes = 0;   end
			     7'b00_10_01_0:begin isNanRes = 0; isInfRes = 1; signRes = 0;   end
			     7'b00_10_01_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
				 7'b00_10_10_0:begin isNanRes = 0; isInfRes = 1; signRes = 1;   end
			     7'b00_10_10_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b00_10_11_0:begin isNanRes = 0; isInfRes = 1; signRes = 1;   end
			     7'b00_10_11_1:begin isNanRes = 0; isInfRes = 1; signRes = 1;   end
			     7'b00_11_00_0:begin isNanRes = 0; isInfRes = 1; signRes = 0;   end
			     7'b00_11_00_1:begin isNanRes = 0; isInfRes = 1; signRes = 0;   end
			     7'b00_11_01_0:begin isNanRes = 0; isInfRes = 1; signRes = 0;   end			     
			     7'b00_11_01_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b00_11_10_0:begin isNanRes = 0; isInfRes = 1; signRes = 1;   end
			     7'b00_11_10_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b00_11_11_0:begin isNanRes = 0; isInfRes = 1; signRes = 1;   end
			     7'b00_11_11_1:begin isNanRes = 0; isInfRes = 1; signRes = 1;   end
			     7'b01_00_00_0:begin isNanRes = 0; isInfRes = 0; signRes = 0;   end
			     7'b01_00_00_1:begin isNanRes = 0; isInfRes = 1; signRes = 0;   end
			     7'b01_00_01_0:begin isNanRes = 0; isInfRes = 0; signRes = 1;   end
			     7'b01_00_01_1:begin isNanRes = 0; isInfRes = 1; signRes = 1;   end
			     7'b01_00_10_0:begin isNanRes = 0; isInfRes = 0; signRes = 0;   end
			     7'b01_00_10_1:begin isNanRes = 0; isInfRes = 1; signRes = 0;   end
			     7'b01_00_11_0:begin isNanRes = 0; isInfRes = 0; signRes = 1;   end
			     7'b01_00_11_1:begin isNanRes = 0; isInfRes = 1; signRes = 1;   end
			     7'b01_01_00_0:begin isNanRes = 1; isInfRes = 0; signRes = 0;   end
			     7'b01_01_00_1:begin isNanRes = 1; isInfRes = 0; signRes = 0;   end
			     7'b01_01_01_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b01_01_01_1:begin isNanRes = 0; isInfRes = 0; signRes = 1;   end
			     7'b01_01_10_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b01_01_10_1:begin isNanRes = 1; isInfRes = 0; signRes = 0;   end
			     7'b01_01_11_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b01_10_00_0:begin isNanRes = 1; isInfRes = 0; signRes = 0;   end
			     7'b01_10_00_1:begin isNanRes = 1; isInfRes = 0; signRes = 0;   end
			     7'b01_10_01_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b01_10_01_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b01_10_10_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b01_10_10_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b01_10_11_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b01_10_11_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b01_11_00_0:begin isNanRes = 1; isInfRes = 0; signRes = 0;   end
			     7'b01_11_00_1:begin isNanRes = 1; isInfRes = 0; signRes = 0;   end
			     7'b01_11_01_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b01_11_01_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b01_11_10_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b01_11_10_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b01_11_11_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b10_00_00_0:begin isNanRes = 0; isInfRes = 0; signRes = 0;   end
			     7'b10_00_00_1:begin isNanRes = 0; isInfRes = 1; signRes = 0;   end
			     7'b10_00_01_0:begin isNanRes = 0; isInfRes = 0; signRes = 1;   end
			     7'b10_00_01_1:begin isNanRes = 0; isInfRes = 1; signRes = 1;   end
			     7'b10_00_10_0:begin isNanRes = 0; isInfRes = 0; signRes = 0;   end
			     7'b10_00_10_1:begin isNanRes = 0; isInfRes = 1; signRes = 0;   end
			     7'b10_00_11_0:begin isNanRes = 0; isInfRes = 0; signRes = 1;   end
			     7'b10_00_11_1:begin isNanRes = 0; isInfRes = 1; signRes = 1;   end
			     7'b10_01_00_0:begin isNanRes = 1; isInfRes = 0; signRes = 0;   end
			     7'b10_01_00_1:begin isNanRes = 1; isInfRes = 0; signRes = 0;   end
			     7'b10_01_01_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b10_01_01_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b10_01_10_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b10_01_10_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b10_01_11_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b10_01_11_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b10_10_00_0:begin isNanRes = 1; isInfRes = 0; signRes = 0;   end
			     7'b10_10_00_1:begin isNanRes = 1; isInfRes = 0; signRes = 0;   end
			     7'b10_10_01_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b10_10_01_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b10_10_10_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b10_10_10_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b10_10_11_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b10_10_11_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b10_11_00_0:begin isNanRes = 1; isInfRes = 0; signRes = 0;   end
			     7'b10_11_00_1:begin isNanRes = 1; isInfRes = 0; signRes = 0;   end
			     7'b10_11_01_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b10_11_01_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b10_11_10_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b10_11_10_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b10_11_11_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b10_11_11_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b11_00_00_0:begin isNanRes = 0; isInfRes = 0; signRes = 0;   end
			     7'b11_00_00_1:begin isNanRes = 0; isInfRes = 1; signRes = 0;   end
			     7'b11_00_01_0:begin isNanRes = 0; isInfRes = 0; signRes = 1;   end
			     7'b11_00_01_1:begin isNanRes = 0; isInfRes = 1; signRes = 1;   end
			     7'b11_00_10_0:begin isNanRes = 0; isInfRes = 0; signRes = 0;   end
			     7'b11_00_10_1:begin isNanRes = 0; isInfRes = 1; signRes = 0;   end
			     7'b11_00_11_0:begin isNanRes = 0; isInfRes = 0; signRes = 1;   end
			     7'b11_00_11_1:begin isNanRes = 0; isInfRes = 1; signRes = 1;   end
			     7'b11_01_00_0:begin isNanRes = 1; isInfRes = 0; signRes = 0;   end
			     7'b11_01_00_1:begin isNanRes = 1; isInfRes = 0; signRes = 0;   end
			     7'b11_01_01_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b11_01_01_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b11_01_10_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b11_01_10_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b11_01_11_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b11_01_11_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b11_10_00_0:begin isNanRes = 1; isInfRes = 0; signRes = 0;   end
			     7'b11_10_00_1:begin isNanRes = 1; isInfRes = 0; signRes = 0;   end
			     7'b11_10_01_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b11_10_01_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b11_10_10_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b11_10_10_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b11_10_11_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b11_11_00_0:begin isNanRes = 1; isInfRes = 0; signRes = 0;   end
			     7'b11_11_00_1:begin isNanRes = 1; isInfRes = 0; signRes = 0;   end
			     7'b11_11_01_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b11_11_01_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b11_11_10_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b11_11_10_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b11_11_11_0:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
			     7'b11_11_11_1:begin isNanRes = 1; isInfRes = 0; signRes = 1;   end
		     
			endcase
		end
		
		return {isValidRes, isInfRes, isNanRes, signRes};
		
		
	endfunction    

endpackage 
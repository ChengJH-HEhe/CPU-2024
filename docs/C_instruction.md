## C-type category. 
  (list from dzh & llz, demonstration by myself)

special Ins
| c.jr 
| c.jalr
| c.lui 

CB: c.beqz 
| c.bnez
CJ: c.jal 
| c.j

L:
CL: c.lw
| c.lwsp

S:
CSS: c.swsp 
CS: c.sw

CR: c.add ADD
| c.sub SUB
| c.xor XOR
| c.or OR
| c.and AND
| c.mv


CI: c.li  OP=10
  | c.addi16sp 
  | c.srli 
  | c.srai 
  | c.andi  
  | c.addi 
  | c.slli 
CIW: c.addi4spn

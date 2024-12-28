### branch-prediction

b-predictor, ifetcher, rob, 

ROB update b-predictor result.

### wrong wire:

rs,lsb: public (broadcast)

rs -> broadcast: not alu 

### predicting jump protocol.
- b-jump:
  1. when will pc[0] be the result of prediction.?
  - b-predictor predict new ins with this pc, output to ifetcher
  - decoder receive from ifetcher: pc & ins
answer:
  memctrl->icache->ifetcher
ask:
  ifetcher->bp->ifetcher->icache
calc:
  alu->(result)rob->ifetcher(clear)&bp(result), no need jump,reg.

### debug.

12.25. icache, pc predict width mistaken(1->32)
12.26. rs, lsb, update dep, reg name mistaken.
12.27. load not head, rd_head != commit_id

### c-extension:

opcode determine the 0~15

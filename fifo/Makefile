# make sim     : scoreboard testbench over several clock ratios (Icarus Verilog)
# make formal  : SymbiYosys unbounded proof (abc pdr) + reachability (cover) + bounded check
CFGS = "10 10 50 50" "10 14 70 70" "7 29 90 90" "29 7 90 90" "10 10 100 100" "10 10 100 10" "10 10 10 100"
sim:
	@for c in $(CFGS); do set -- $$c; \
	  iverilog -g2012 -o tb.vvp -P tb_async_fifo.WPER=$$1 -P tb_async_fifo.RPER=$$2 \
	    -P tb_async_fifo.WPROB=$$3 -P tb_async_fifo.RPROB=$$4 tb_async_fifo.sv async_fifo.sv 2>/dev/null; \
	  vvp -n tb.vvp | grep tb_async_fifo; done
formal:
	sby -f fifo.sby prove
	sby -f fifo.sby cover
	sby -f bmc.sby
clean:
	rm -rf tb.vvp fifo_prove fifo_cover bmc fifo.smt2

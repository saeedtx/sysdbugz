#!/bin/env python


# This script is used to compare the /proc/interrupt output of two different collections
# The output of this script is a list of IRQs that have changed between the two collections
# The output is a list of sorted IRQs that have changed between the two collections

from copy import deepcopy
import sys
import os
import argparse

if len(sys.argv) < 2:
	print(f"Usage: {sys.argv[0]} <file1> <file2>")
	sys.exit(1)

def parse_args():
	parser = argparse.ArgumentParser(description='This script is used to compare the /proc/interrupt output of two different collections')
	parser.add_argument('file1', help='The first file to compare')
	parser.add_argument('file2', help='The second file to compare')
	parser.add_argument('names', help='names of irqs to sum', default=[], nargs='*')
	args = parser.parse_args()
	return args

def read_file_lines(filename):
	lines = []
	with open(filename, 'r') as f:
		for line in f:
			lines.append(line.strip())
	return lines

class IRQ(object):
	def __init__(self, irqID, cpu_ints, irq_name, irq_edge, irq_type, irq_info):
		self.ID = irqID
		self.cpu_ints = cpu_ints
		self.name = irq_name
		self.edge = irq_edge
		self.type = irq_type
		self.info = irq_info
		self.sum_int = sum(cpu_ints)

	def __repr__(self):
		info = f"name: {self.name}  type: {self.type}" if self.name else self.info
		obj_id = id(self)
		return f"IRQ: {self.ID} {self.sum_int} {info}"

	def __eq__(self, other):
		return self.ID == other.ID and self.name == other.name

	def __hash__(self):
		return hash((self.ID, self.name))

	# - operator return a new DIFF IRQ object
	def __sub__(self, other):
		if self != other:
			raise ValueError(f"Cannot subtract IRQs that are not the same IRQ ID and name, {self} != {other}")
		# subtract the cpu ints
		cpu_ints = []
		for i in range(len(self.cpu_ints)):
			cpu_ints.append(self.cpu_ints[i] - other.cpu_ints[i])
		return IRQ(self.ID, cpu_ints, self.name, self.edge, self.type, self.info)


# file format is:
# 1ST LINE: CPU0 CPU1 CPU2 CPU3 CPU4 CPU5 CPU6 CPU7 CPU8 CPU9 CPU10 ... CPUN
# 2ND..Last LINE: #IRQ: 0 0 0 0 0 0 0 0 0 0 0 ... 0  [TYPE] [EDGE] [NAME]
def read_irqs(filename):
	lines = read_file_lines(filename)
	irqs = {}
	cpus = lines[0].split()
	for irq in lines[1:]:
		irq = irq.split()
		irqID = irq[0][:-1] # remove the colon
		int_per_cpu = [int(cpu_int) for cpu_int in irq[1:len(cpus)+1]]
		info=irq[len(cpus)+1:]
		irq_name, irq_edge, irq_type = "", "", ""
		irq_info=" ".join(info)
		# if irqID not type int, then it is a summary line
		if irqID.isdigit():
			if len(info) > 0:
				irq_type = info[0]
			if len(info) > 1:
				irq_edge = info[1]
			if len(info) > 2:
				irq_name = info[2]

		irq = IRQ(irqID, int_per_cpu, irq_name, irq_edge, irq_type, irq_info)
		irqs[irq.ID] = irq
	return irqs

def diff_irqs(irqs1, irqs2):
	diff = deepcopy(irqs2)
	for irqid in irqs1:
		if not irqid in irqs2:
			diff[irqid] = irqs1[irqid]
			continue
		diff[irqid] = irqs2[irqid] - irqs1[irqid]
	return diff

def sum_irqs_by_name(irqs, irq_name):
	sum = 0
	for irqid, irq in irqs.items():
		if irq_name in irq.name:
			sum += irq.sum_int
	return sum

# find irqs with names end with @pci:<pci_id> and group them by pci_id
# example irq name @pci:0000:00:1c.0
def group_irqs_by_pci(irqs):
	pci_irqs = {}
	for irqid, irq in irqs.items():
		if "@pci" in irq.name:
			#pci_id = irq.name.split(":")[1:]
			cut_idx = irq.name.find("@pci")
			pci_id = irq.name[cut_idx+5:]
			#print("found pci irq", irq.name, pci_id)
			if not pci_id in pci_irqs:
				pci_irqs[pci_id] = []
			pci_irqs[pci_id].append(irq)
	return pci_irqs

if __name__ == "__main__":
	args = parse_args()
	print(f"Comparing {args.file1} to {args.file2}")
	irqs1 = read_irqs(args.file1)
	irqs2 = read_irqs(args.file2)
	diff = diff_irqs(irqs1, irqs2)
	total_int = 0
	for irqid, irq in sorted(diff.items(), key=lambda x: x[1].sum_int):
		total_int += irq.sum_int
		if irq.sum_int > 0:
			print(irq)
	print(f"Total interrupts: {total_int}")

	pci_irqs = group_irqs_by_pci(diff)
	# print sum of all irq.sum_int
	print("GROUP by PCI IRQs:")
	for pci_id, irqs in pci_irqs.items():
		#print(f"PCI: {pci_id}")
		sum_int = 0
		for irq in irqs:
			sum_int += irq.sum_int
		print(f"PCI: {pci_id} sum: {sum_int}")

	# sum given irqs by names
	#for irq_name in args.names:
	#	sum = sum_irqs_by_name(irqs2, irq_name)
	#	print(f"{irq_name} sum: {sum}")






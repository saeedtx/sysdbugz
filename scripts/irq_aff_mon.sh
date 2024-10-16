#!/bin/bash

string=$1
interval=$2
duration=$3

echo "Monitoring IRQs with \"$string\" in their names every $interval seconds for $duration seconds"
irq_list=$(grep -E "$string" /proc/interrupts | awk '{print $1}')

irq_list=${irq_list//:/}

declare -A irq_names; declare -A smp_before; declare -A eff_before

for irq in $irq_list; do
	irq_names[$irq]=$(grep -E "$string" /proc/interrupts | grep -E "^$irq:" | awk '{print $NF}')
	smp_before[$irq]=$(cat /proc/irq/$irq/smp_affinity)
	eff_before[$irq]=$(cat /proc/irq/$irq/effective_affinity)
done

while [ $duration -gt 0 ]; do
for irq in $irq_list; do
	irq_dir=/proc/irq/$irq
	irq_name=${irq_names[$irq]}
	smp_affinity=$(cat "$irq_dir"/smp_affinity)
	effective_affinity=$(cat "$irq_dir"/effective_affinity)

	if [ "$smp_affinity" != "${smp_before[$irq]}" ] || [ "$effective_affinity" != "${eff_before[$irq]}" ]; then
		printf "[%s] [%s][%s] Affinity changed\n" "$(date +"%T")" "$irq" "$irq_name"
		printf "  SMP Before: %s\n" "${smp_before[$irq]}"
		printf "  SMP After : %s\n" "$smp_affinity"
		printf "  Eff Before: %s\n" "${eff_before[$irq]}"
		printf "  Eff After : %s\n" "$effective_affinity"
	fi

	smp_before[$irq]=$smp_affinity
	eff_before[$irq]=$effective_affinity
done

duration=$((duration - interval))
sleep $interval
done
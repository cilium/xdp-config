#!/bin/bash -e
# SPDX-License-Identifier: (GPL-2.0-only OR BSD-2-Clause)

# Usage:   ./affinity.sh <netdev> <cpus>
# Example: ./affinity.sh enp10s0f0np0 0-31

DEV=$1
CPUL=$2
NODE=0 #$(cat /sys/bus/pci/devices/$DEV/numa_node)

killall irqbalance 2> /dev/null || true
[ -z "$CPUL" ] && CPUL=$(cat /sys/bus/node/devices/node${NODE}/cpulist | tr ',' ' ')
for c in $CPUL; do
    [[ "$c" =~ '-' ]] && c=$(seq $(echo $c | tr '-' ' '))
    CPUS=(${CPUS[@]} $c)
done
IRQS=$(ls /sys/class/net/$DEV/device/msi_irqs/)
IRQS=($IRQS)
id=0
ethtool -l $DEV
echo -e "Setting device $DEV affinity to CPUs $CPUL for ${#IRQS[@]} IRQs:"
for i in $(seq 0 $((${#IRQS[@]} - 1)))
do
    IRQ=${IRQS[i]}
    ! [ -e /proc/irq/$IRQ ] && continue
    CPU=${CPUS[id % ${#CPUS[@]}]}
    echo $CPU > /proc/irq/$IRQ/smp_affinity_list
    STATE="irq: $(cat /proc/irq/$IRQ/smp_affinity_list) / $(cat /proc/irq/$IRQ/smp_affinity)"
    echo -e "-> pinning IRQ $IRQ to CPU $CPU ($STATE)"
    ((++id))
done

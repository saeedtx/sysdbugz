#!/usr/bin/env python

import sys
import os
import re

# Read ethtool stats files with name format: <index>-<timestamp>-<time_interval>.txt 
# arrange them in a table with rows of: <index>, <timestamp>, <time_interval>,  <delta timestamp>, <stat_name1>, <stat_name2>, ...

def list_ethtool_files(directory):
        files = []
        for filename in os.listdir(directory):
                if filename.endswith(".txt"):
                        files.append(os.path.join(directory, filename))
        return files

def read_ethtool_file(filename):
        lines = []
        with open(filename) as f:
                lines = f.readlines()
        return lines

def parse_ethtool_file(lines):
        stats = {}
        for line in lines:
                if re.match(r'^\s+.*:\s+\d+', line):
                        stat = line.split(':')[0].strip()
                        value = line.split(':')[1].strip()
                        stats[stat] = value
        return stats

def create_table_row(file):
        row = []
        file_name=os.path.basename(file)
      #  print(file_name)
      #  print(file_name.split('-')[0])
        row.append(int(file_name.split('-')[0])) # index
        row.append(int(file_name.split('-')[1])) # timestamp
        row.append(int(file_name.split('-')[2].split('.')[0])) # time interval
        lines = read_ethtool_file(file)
        stats = parse_ethtool_file(lines)
        row.append(0) # place holder for delta timestamp
        for stat in stats:
                row.append(stats[stat])
        return row

def create_table(directory):
        files = list_ethtool_files(directory)
        table = []
        for file in files:
                row = create_table_row(file)
                table.append(row)
        # sort according to index
        table.sort(key=lambda x: x[0])
        return table

def calc_ealpsed_time(table):
        for i in range(len(table)-1, 0, -1):
                table[i][3] = table[i][1] - table[0][1]

def calc_delta_stats(table):
        for row in range(len(table)-1, 0, -1):
                for col in range(4, len(table[row])):
                        table[row][col] = int(table[row][col]) - int(table[row-1][col])

def create_table_header(directory):
        header = []
        header.append('index')
        header.append('timestamp')
        header.append('time interval')
        header.append('delta timestamp')
        lines = read_ethtool_file(list_ethtool_files(directory)[0])
        stats = parse_ethtool_file(lines)
        for stat in stats:
                header.append(stat)
        return header
      
def print_table(table, header):
        print(','.join(header))
        for row in table[0:10]:
                print(','.join(str(x) for x in row))

# use import matplotlib.pyplot as plt to plot the graph
def plot_stats_timetable_graph(tstamps, values, list_of_stats):
        for stat in list_of_stats:
                print('plotting ' + stat)
        import matplotlib.pyplot as plt
        import numpy as np
        # find all indexes of list_stats in headers'
        color_table = ['r', 'g', 'b', 'y', 'm', 'c']
        markers = ['o', 'v', '^', '<', '>', 's']
        c = 0
        for row in values:
                plt.plot(tstamps, row, linestyle='-', marker = f"{markers[c]}", color=f"{color_table[c]}")
                c += 1
 
 #       plt.plot(tstamps, rx_packets, marker='o', linestyle='-', color='r')
        plt.xlabel('Time (ms)')
        plt.ylabel('rx_packets')
        plt.title('Time Series Plot')
        plt.grid(True)
        plt.show()

if __name__ == "__main__":
        directory = sys.argv[1]
        table = create_table(directory)
        calc_ealpsed_time(table)
        print(table[0:5])
        calc_delta_stats(table)
        table=table[1:]
        header = create_table_header(directory)
        print("-----------------")
        count=10
        print(header[0:count])
        print("-----------------")
        list_stats = ['rx_packets', 'rx_out_of_buffer', 'rx_vport_unicast_packets']
        # print index, delta timestamp, rx_packets, rx_out_of_buffer
        #table = 
       # table = table[0:count]
        # filter out rows with row[4] = 0
        table = [row for row in table if row[4] != 0]
        table = table[0:1000]
        indexes = [header.index(stat) for stat in list_stats]
        values = [ [] for i in indexes]
        timestamsp = []
        for row in table:
             #   values.append([])
                r=0
                for i in indexes:
                        values[r].append(row[i])
                        r+=1
                        #values.append(row[i])
                timestamsp.append(row[3]) # delta timestamp
        for val in values:
                print(val)
        # filter out rows with row[4] = 0
  
        #print_table(table, header)
        plot_stats_timetable_graph(timestamsp, values, list_stats)

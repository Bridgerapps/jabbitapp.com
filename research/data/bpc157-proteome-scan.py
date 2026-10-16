#!/usr/bin/env python3
"""Scan every human protein in UniProtKB (reviewed + unreviewed, organism_id 9606) for the BPC-157 sequence.
Download used 2026-10-16: https://rest.uniprot.org/uniprotkb/stream?query=organism_id:9606&format=fasta&compressed=true
Result 2026-10-16: 210,706 sequences; exact matches 0; ungapped 15-residue windows with >=10/15 identical: 0."""
import gzip,sys
q='GEPPPGKPADDAGLV'; seqs={}; name=None; buf=[]
for line in gzip.open(sys.argv[1],'rt'):
    if line.startswith('>'):
        if name: seqs[name]=''.join(buf)
        name=line[1:].strip(); buf=[]
    else: buf.append(line.strip())
if name: seqs[name]=''.join(buf)
exact=[n for n,s in seqs.items() if q in s]
best=max((sum(a==b for a,b in zip(s[i:i+15],q)),n) for n,s in seqs.items() for i in range(len(s)-14))
print('sequences',len(seqs),'exact',len(exact),'best window identity',best[0],'/15',best[1][:80])

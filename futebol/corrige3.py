import json, collections
ARQ='elencos.json'
d=json.load(open(ARQ,encoding='utf-8'))
antes=len(d['times'])
d['times']=[x for x in d['times'] if x['id']!='fla23']
print(f'Flamengo 2023 removido ({antes} -> {len(d["times"])} times)')
T={x['id']:x for x in d['times']}
for tid,f in [('cru13',"Wikipédia / Edição dos Campeões — elenco do Brasileiro de 2013 (nomes-chave conferidos, XI não confirmado)"),
              ('cru14',"Wikipédia — elenco do Brasileiro de 2014 (nomes-chave conferidos, XI não confirmado)"),
              ('san02',"Santos FC / Imortais — elenco de 2002 (XI da final não localizado)")]:
    T[tid]['fonte']=f; T[tid]['fonte_parcial']=True

erros=[]; nomes=collections.defaultdict(set)
for x in d['times']:
    if len(x['elenco'])!=11: erros.append(f"{x['id']}: {len(x['elenco'])}")
    g=collections.Counter(j['grupo'] for j in x['elenco'])
    for k,mn in [('GOL',1),('DEF',3),('MEI',2),('ATA',1)]:
        if g[k]<mn: erros.append(f"{x['id']}: so {g[k]} {k}")
    for j in x['elenco']: nomes[j['id']].add(j['nome'])
for k,v in nomes.items():
    if len(v)>1: erros.append(f"id {k}: {v}")
print('ERROS:', erros if erros else 'nenhum')
if not erros:
    json.dump(d, open(ARQ,'w',encoding='utf-8'), ensure_ascii=False, indent=1)
    parc=[x['clube']+' '+str(x['ano']) for x in d['times'] if x.get('fonte_parcial')]
    print(f"times: {len(d['times'])} | entradas: {sum(len(x['elenco']) for x in d['times'])} | unicos: {len(nomes)}")
    print('todos com fonte:', all(x.get('fonte') for x in d['times']))
    print('fonte parcial:', ', '.join(parc))

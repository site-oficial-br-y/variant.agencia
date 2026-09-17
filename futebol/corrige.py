import json, collections
ARQ='elencos.json'
d=json.load(open(ARQ,encoding='utf-8'))
T={x['id']:x for x in d['times']}

def troca(tid, id_sai, novo, fonte=None):
    t=T[tid]
    for i,j in enumerate(t['elenco']):
        if j['id']==id_sai:
            t['elenco'][i]=novo; break
    else:
        raise SystemExit(f'{tid}: nao achei {id_sai}')
    if fonte: t['fonte']=fonte
def J(i,n,pos,g,o): return {"id":i,"nome":n,"pos":pos,"grupo":g,"over":o}
def confirma(tid,fonte): T[tid]['fonte']=fonte

# --- confirmados sem mudanca ---
confirma('san62',"CONMEBOL — time campeão da América de 1962")
confirma('fla81',"Flamengo / Imortais — escalação da final do Mundial de 1981")
confirma('spfc92',"São Paulo FC — escalação da final do Mundial de 1992")
confirma('spfc93',"São Paulo FC — escalação da final do Mundial de 1993")
confirma('pal99',"Wikipédia / ogol — escalação da final da Libertadores de 1999")
confirma('fla19',"Coluna do Fla — escalação da final da Libertadores de 2019")
confirma('fla22',"Wikipédia / ESPN — escalação da final da Libertadores de 2022")
confirma('pal94',"Goal — escalação da final do Brasileiro de 1994")
confirma('flu12',"Campeões do Futebol — elenco e jogo do título de 2012")

# --- correcoes ---
troca('gre95','magno-gre', J("arilson","Arílson","Meia","MEI",79),
      "Imortais do Futebol — Grêmio 1994-1997, time da Libertadores de 95")
troca('cor12','douglas-cor', J("guerrero","Paolo Guerrero","Centroavante","ATA",85),
      "Goal / Wikipédia — escalação da final do Mundial de 2012")
troca('cam13','junior-cesar', J("richarlyson","Richarlyson","Lateral-esquerdo","DEF",78),
      "Goal — escalação da final da Libertadores de 2013")
troca('spfc05','grafite', J("edcarlos","Edcarlos","Zagueiro","DEF",78),
      "São Paulo FC — escalação da final do Mundial de 2005")
troca('san11','henrique-san', J("adriano-san","Adriano","Volante","MEI",78))
troca('san11','borges', J("ze-eduardo","Zé Eduardo","Centroavante","ATA",77),
      "ESPN / Wikipédia — escalação da final da Libertadores de 2011")
troca('pal21','marcos-rocha', J("mayke","Mayke","Lateral-direito","DEF",79))
troca('pal21','deyverson', J("gustavo-scarpa","Gustavo Scarpa","Meia","MEI",83),
      "Wikipédia / ESPN — escalação da final da Libertadores de 2021")
troca('pal20','willian-pal', J("gabriel-menino","Gabriel Menino","Volante","MEI",78),
      "ogol / Palmeiras — escalação da final da Libertadores de 2020")
troca('flu23','nino', J("marlon-flu","Marlon","Zagueiro","DEF",79))
troca('flu23','martinelli', J("lima-flu","Lima","Volante","MEI",78),
      "Wikipédia / ESPN — escalação da final da Libertadores de 2023")
troca('bot24','bastos', J("adryelson","Adryelson","Zagueiro","DEF",79),
      "Wikipédia / CNN — escalação da final da Libertadores de 2024")
troca('int10','giuliano', J("sandro-int","Sandro","Volante","MEI",80))
troca('int10','alecsandro', J("taison","Taison","Ponta","ATA",82),
      "ogol — escalação da final da Libertadores de 2010")

erros=[]; nomes=collections.defaultdict(set)
for x in d['times']:
    if len(x['elenco'])!=11: erros.append(f"{x['id']}: {len(x['elenco'])}")
    g=collections.Counter(j['grupo'] for j in x['elenco'])
    for k,mn in [('GOL',1),('DEF',3),('MEI',2),('ATA',1)]:
        if g[k]<mn: erros.append(f"{x['id']}: so {g[k]} {k}")
    for k,v in collections.Counter(j['id'] for j in x['elenco']).items():
        if v>1: erros.append(f"{x['id']} repete {k}")
    for j in x['elenco']: nomes[j['id']].add(j['nome'])
for k,v in nomes.items():
    if len(v)>1: erros.append(f"id {k}: {v}")
print('ERROS:', erros if erros else 'nenhum')
if not erros:
    json.dump(d, open(ARQ,'w',encoding='utf-8'), ensure_ascii=False, indent=1)
    comf=[x['id'] for x in d['times'] if x.get('fonte')]
    semf=[x['clube']+' '+str(x['ano']) for x in d['times'] if not x.get('fonte')]
    print(f'times: {len(d["times"])} | com fonte: {len(comf)} | sem fonte: {len(semf)}')
    print('ainda sem conferir:', ', '.join(semf))

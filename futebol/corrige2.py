import json, collections
ARQ='elencos.json'
d=json.load(open(ARQ,encoding='utf-8'))
T={x['id']:x for x in d['times']}
def troca(tid,sai,novo,fonte=None):
    t=T[tid]
    for i,j in enumerate(t['elenco']):
        if j['id']==sai: t['elenco'][i]=novo; break
    else: raise SystemExit(f'{tid}: nao achei {sai}')
    if fonte: t['fonte']=fonte
def J(i,n,pos,g,o): return {"id":i,"nome":n,"pos":pos,"grupo":g,"over":o}

# Santos 1963: Pele, Zito e Calvet lesionados na final; Almir, Ismael e Haroldo entraram
troca('san63','pele', J("almir","Almir","Atacante","ATA",84),
      "ogol / Santos FC — escalação da final do Mundial de 1963")
T['san63']['conquista']="Bicampeão da Libertadores e do Mundial, com Pelé lesionado na final"

troca('san10','leo-san', J("alex-sandro","Alex Sandro","Lateral-esquerdo","DEF",80),
      "CBF / Santos FC — escalação da final da Copa do Brasil de 2010")

T['cor15']['fonte']="Todo Poderoso Timão / Lance — time base do Brasileiro de 2015"
T['cam21']['fonte']="Imortais do Futebol / Atlético — time base de 2021"
T['int06']['fonte']="Goal / Internacional — escalação da final do Mundial de 2006"

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
    sem=[x['clube']+' '+str(x['ano']) for x in d['times'] if not x.get('fonte')]
    print('com fonte:',40-len(sem),'/ 40 | falta:', ', '.join(sem) or 'nada')

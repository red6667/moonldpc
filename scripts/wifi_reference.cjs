const fs = require('fs');
const vm = require('vm');
const path = require('path');
const dir = process.argv[2];
if (!dir) throw Error("Pass the directory containing hash-verified upstream files");
const ctx = vm.createContext({console});
for (const [file, symbol] of [['reference-matrices.js','codes80211n'],['reference-util.js','Util'],['reference-codetable.js','CodeTable'],['reference-encoder.js','LdpcEncoder'],['reference-testdata.js','Data']]) {
 let text=fs.readFileSync(path.join(dir,file),'utf8').replace(/^import .*;\s*$/mg,'').replace(/export (const|class) /g,'$1 ');
 vm.runInContext(text + '\nglobalThis.'+symbol+' = '+symbol+';',ctx,{filename:file});
}
const table = new ctx.CodeTable();
const code = table.codes['3/4']['1944'];
const encoder = new ctx.LdpcEncoder(code);
const input = ctx.Util.bytesToBitsBE(ctx.Data.shortened1).slice(0,1458);
const expected = ctx.Util.bytesToBitsBE(ctx.Data.encoded1);
const actual = encoder.encode(input);
if(JSON.stringify(actual)!==JSON.stringify(expected)) throw Error('upstream Annex G mismatch');
if(ctx.Util.multiplySparse(code.H,actual).some(x=>x)) throw Error('upstream syndrome');
const cases = [{name:'annex-g-example-1',input,expected}];
for(const [name,make] of [ ['zero', i=>0],['ones',i=>1], ['alternating',i=>i%2], ['first',i=>i===0?1:0], ['last',i=>i===1457?1:0],['stride-17',i=>i%17===3?1:0] ]) {
 const s=Array.from({length:1458},(_,i)=>make(i));
 cases.push({name,input:s,expected:Array.from(encoder.encode(s))});
}
const reference={profile:'IEEE 802.11 LDPC n=1944 rate=3/4',n:1944,k:1458,z:81,base:Array.from(code.Hb,r=>Array.from(r)),cases,annex_final_bits:Array.from(ctx.Util.bytesToBitsBE(ctx.Data.final1))};
console.log(JSON.stringify(reference));

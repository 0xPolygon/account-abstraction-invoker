import fs from "fs";

const out = "scripts/tracking/out/";
const record = out + "record.json";

function read() {
  if (fs.existsSync(record)) {
    const data = fs.readFileSync(record, "utf-8");
    return JSON.parse(data.toString());
  } else {
    return undefined;
  }
}

function write(obj: any) {
  const data = JSON.stringify(obj);
  if (!fs.existsSync(out)) fs.mkdirSync(out);
  fs.writeFileSync(record, data);
}

export { read, write };

import payload from "./payload.json";
import sign from "./sign";

export default function getSignature(message: any, privateKey: string) {
  const typedData = {
    ...payload,
    message,
  };

  return sign(typedData, privateKey);
}

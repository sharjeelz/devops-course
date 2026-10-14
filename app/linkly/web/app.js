const $ = (id) => document.getElementById(id);
let code = null;

async function refresh() {
  if (!code) return;
  const res = await fetch(`/api/links/${code}`);
  if (res.ok) $("clicks").textContent = (await res.json()).clicks;
}

$("shorten").addEventListener("submit", async (e) => {
  e.preventDefault();
  $("error").hidden = true;
  const res = await fetch("/api/links", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ url: $("url").value }),
  });
  if (!res.ok) {
    $("error").textContent = res.status === 422 ? "That doesn't look like a web address." : `Something went wrong (${res.status}).`;
    $("error").hidden = false;
    return;
  }
  const link = await res.json();
  code = link.code;
  $("short").href = $("short").textContent = link.short_url;
  $("clicks").textContent = "0";
  $("result").hidden = false;
});

$("refresh").addEventListener("click", refresh);

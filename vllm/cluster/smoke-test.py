import ray
import socket
import requests

# 初始化 Ray (如果还没连接，请填写你的 ray address)
ray.init(ignore_reinit_error=True)

@ray.remote
def check_network():
    node_ip = ray.util.get_node_ip_address()
    target = "huggingface.co"
    results = {"ip": node_ip, "dns": "FAILED", "http": "FAILED", "error": ""}
    
    # 1. 测试 DNS 解析
    try:
        socket.gethostbyname(target)
        results["dns"] = "PASSED"
    except Exception as e:
        results["error"] = f"DNS Error: {str(e)}"
        return results

    # 2. 测试 HTTPS 连接 (超时设为 5 秒)
    try:
        response = requests.head(f"https://{target}", timeout=5)
        results["http"] = f"PASSED (Status: {response.status_code})"
    except Exception as e:
        results["http"] = "FAILED"
        results["error"] = f"HTTP Error: {str(e)}"
        
    return results

# 获取所有活跃节点并执行
nodes = ray.nodes()
active_nodes = [node for node in nodes if node['Alive']]
print(f"检测到 {len(active_nodes)} 个活跃节点，正在排查...")

futures = [check_network.remote() for _ in range(len(active_nodes))]
results = ray.get(futures)

# 打印结果表格
print(f"{'Node IP':<20} | {'DNS':<10} | {'HTTP/HTTPS':<15} | {'Notes'}")
print("-" * 70)
for res in results:
    print(f"{res['ip']:<20} | {res['dns']:<10} | {res['http']:<15} | {res['error']}")
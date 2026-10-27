async fn slow_hello() -> String {
    "hello form an async function".to_string()
}

#[tokio::main]
async fn main() {
    let greeting = slow_hello().await;

    println!("{}", greeting);
}

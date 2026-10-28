use axum::{
    Router,
    extract::{Path, Query},
    routing::get,
};

use std::collections::HashMap;

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/", get(root))
        .route("/health", get(health))
        .route("/tasks", get(list_tasks).post(create_task))
        .route("/tasks/{id}", get(get_task));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();

    println!("taskr running on http://localhost:3000");

    axum::serve(listener, app).await.unwrap();
}

async fn root() -> &'static str {
    "taskr is alive"
}

async fn health() -> &'static str {
    "ok"
}

async fn list_tasks(Query(params): Query<HashMap<String, String>>) -> String {
    let filter = params
        .get("done")
        .map_or("everything".to_string(), |v| format!("done={}", v));

    format!("listing tasks, filter: {}", filter)
}

async fn create_task() -> &'static str {
    "a task will be created here"
}

async fn get_task(Path(id): Path<u32>) -> String {
    format!("you asked for task {}", id)
}

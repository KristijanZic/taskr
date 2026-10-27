struct Task {
    id: u32,
    title: String,
    done: bool,
}

fn main() {
    let mut first = Task {
        id: 1,
        title: "Learn Axum".to_string(),
        done: false,
    };

    first.done = true;

    println!("{} is done: {}", first.title, first.done);
}

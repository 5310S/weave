use yew::prelude::*;

#[function_component(App)]
fn app() -> Html {
    let counter = use_state(|| 0);
    let on_increment = {
        let counter = counter.clone();
        Callback::from(move |_| counter.set(*counter + 1))
    };
    let on_decrement = {
        let counter = counter.clone();
        Callback::from(move |_| counter.set(*counter - 1))
    };

    html! {
        <div class="flex flex-col items-center justify-center min-h-screen bg-gray-100">
            <h1 class="text-4xl font-bold mb-4">{"Rust Yew Counter"}</h1>
            <p class="text-2xl mb-4">{*counter}</p>
            <div class="space-x-4">
                <button
                    onclick={on_decrement}
                    class="px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600"
                >
                    {"Decrement"}
                </button>
                <button
                    onclick={on_increment}
                    class="px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600"
                >
                    {"Increment"}
                </button>
            </div>
        </div>
    }
}

fn main() {
    yew::Renderer::<App>::new().render();
}
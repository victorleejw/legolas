import React from 'react';
import { Route, Link } from 'react-router-dom';
import Logo from './logo/logo';
import Search from './search/search';
import SignUpPage from './user/sign_up_page';

const App = props => (
  <div className="app">
    <header>
      <Logo />
      <Search />
    </header>
    <main>
      <Route exact path="/" render={() => <h1>Welcome to Legolas</h1>} />
      <Route path="/sign_up" component={SignUpPage} />
    </main>
  </div>
);

export default App;
